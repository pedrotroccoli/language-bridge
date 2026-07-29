---
tags: [compass, rails, webhooks, security]
see-also:
  - "[[security]]"
  - "[[background-jobs]]"
---

# Webhooks

## SSRF Protection (PR #1196)

Server-Side Request Forgery protection prevents webhooks from hitting internal services:

```ruby
# app/models/concerns/ssrf_protection.rb
module SsrfProtection
  extend ActiveSupport::Concern

  DISALLOWED_IP_RANGES = [
    IPAddr.new("0.0.0.0/8"),        # Current network
    IPAddr.new("10.0.0.0/8"),       # Private A
    IPAddr.new("100.64.0.0/10"),    # Shared address space
    IPAddr.new("127.0.0.0/8"),      # Loopback
    IPAddr.new("169.254.0.0/16"),   # Link-local
    IPAddr.new("172.16.0.0/12"),    # Private B
    IPAddr.new("192.0.0.0/24"),     # IETF protocol assignments
    IPAddr.new("192.168.0.0/16"),   # Private C
    IPAddr.new("::1/128"),          # IPv6 loopback
    IPAddr.new("fc00::/7"),         # IPv6 unique local
    IPAddr.new("fe80::/10"),        # IPv6 link-local
  ].freeze

  def resolve_ip(hostname)
    Resolv.getaddress(hostname)
  rescue Resolv::ResolvError
    raise SsrfProtection::DnsResolutionError, "Could not resolve hostname: #{hostname}"
  end

  def validate_ip!(ip_string)
    ip = IPAddr.new(ip_string)

    if private_address?(ip)
      raise SsrfProtection::PrivateAddressError,
        "Requests to private/internal addresses are not allowed: #{ip_string}"
    end

    ip_string
  end

  def private_address?(ip)
    DISALLOWED_IP_RANGES.any? { |range| range.include?(ip) }
  end

  # IP pinning: resolve DNS once and pin to that IP for the request
  # Prevents DNS rebinding attacks
  def perform_safe_request(url, **options)
    uri = URI.parse(url)
    resolved_ip = resolve_ip(uri.host)
    validate_ip!(resolved_ip)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10
    http.ipaddr = resolved_ip  # Pin to resolved IP

    request = build_request(uri, **options)
    http.request(request)
  end

  class DnsResolutionError < StandardError; end
  class PrivateAddressError < StandardError; end
end
```

---

## Delivery Pattern: Asynchronous with State Machine (PR #1196)

```ruby
# app/models/webhook/delivery.rb
class Webhook::Delivery < ApplicationRecord
  include SsrfProtection

  belongs_to :webhook
  belongs_to :deliverable, polymorphic: true

  enum :status, {
    pending: 0,
    delivered: 1,
    failed: 2,
    timed_out: 3,
    error: 4
  }

  store :request, accessors: %i[
    request_url request_headers request_body
  ], coder: JSON

  store :response, accessors: %i[
    response_code response_headers response_body
  ], coder: JSON

  scope :triggered_by, ->(event) { where(event: event) }

  MAX_RESPONSE_SIZE = 50.kilobytes

  def perform_request
    result = perform_safe_request(
      webhook.url,
      method: :post,
      headers: signed_headers,
      body: payload
    )

    self.response_code = result.code.to_i
    self.response_headers = result.each_header.to_h
    self.response_body = result.body&.truncate(MAX_RESPONSE_SIZE)
    self.status = result.code.to_i.in?(200..299) ? :delivered : :failed

    save!
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    update!(status: :timed_out, response_body: e.message)
  rescue SsrfProtection::PrivateAddressError, SsrfProtection::DnsResolutionError => e
    update!(status: :error, response_body: e.message)
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    update!(status: :error, response_body: e.message)
  rescue StandardError => e
    update!(status: :error, response_body: "Unexpected error: #{e.message}")
  end
end
```

---

## Retry Strategy: Delinquency Tracking (PR #1196)

Instead of exponential backoff retries, track consecutive failures and disable webhooks that are consistently failing:

```ruby
# app/models/webhook/delinquency_tracker.rb
class Webhook::DelinquencyTracker
  DELINQUENCY_THRESHOLD = 10
  DELINQUENCY_DURATION = 1.hour

  attr_reader :webhook

  def initialize(webhook)
    @webhook = webhook
  end

  def record_delivery_of(delivery)
    if delivery.delivered?
      reset
    else
      increment
    end
  end

  def reset
    webhook.update!(
      consecutive_failures: 0,
      delinquent_until: nil
    )
  end

  def delinquent?
    webhook.delinquent_until.present? && webhook.delinquent_until > Time.current
  end

  private

  def increment
    webhook.increment!(:consecutive_failures)

    if webhook.consecutive_failures >= DELINQUENCY_THRESHOLD
      webhook.update!(delinquent_until: DELINQUENCY_DURATION.from_now)
    end
  end
end
```

Usage in the delivery job:

```ruby
class Webhook::DeliveryJob < ApplicationJob
  def perform(delivery)
    tracker = Webhook::DelinquencyTracker.new(delivery.webhook)

    if tracker.delinquent?
      delivery.update!(status: :error, response_body: "Webhook is delinquent - paused delivery")
      return
    end

    delivery.perform_request
    tracker.record_delivery_of(delivery)
  end
end
```

---

## Signature Verification: HMAC-SHA256 (PR #1196)

Allow recipients to verify webhook payloads are authentic:

```ruby
# app/models/webhook.rb
class Webhook < ApplicationRecord
  has_secure_token :signing_secret

  has_many :deliveries, class_name: "Webhook::Delivery", dependent: :destroy

  def sign(payload, timestamp:)
    data = "#{timestamp}.#{payload}"
    OpenSSL::HMAC.hexdigest("SHA256", signing_secret, data)
  end
end
```

```ruby
# In Webhook::Delivery
class Webhook::Delivery < ApplicationRecord
  private

  def signed_headers
    timestamp = Time.current.to_i.to_s
    signature = webhook.sign(payload, timestamp: timestamp)

    {
      "Content-Type" => content_type,
      "X-Webhook-Signature" => signature,
      "X-Webhook-Timestamp" => timestamp,
      "User-Agent" => "Compass-Webhooks/1.0"
    }
  end
end
```

Recipient verification example (for documentation):

```ruby
# How recipients verify the webhook signature
def verify_webhook(payload, headers, signing_secret)
  timestamp = headers["X-Webhook-Timestamp"]
  expected_signature = headers["X-Webhook-Signature"]

  data = "#{timestamp}.#{payload}"
  computed = OpenSSL::HMAC.hexdigest("SHA256", signing_secret, data)

  ActiveSupport::SecurityUtils.secure_compare(computed, expected_signature)
end
```

---

## Background Job Integration (PR #1196)

### Two-Stage Pattern: WebhookDispatchJob + DeliveryJob

```ruby
# app/jobs/webhook_dispatch_job.rb
class WebhookDispatchJob < ApplicationJob
  queue_as :default

  def perform(event:, deliverable:)
    webhooks = deliverable.account.webhooks.active
      .where("events @> ?", [event].to_json)

    webhooks.find_each do |webhook|
      delivery = webhook.deliveries.create!(
        event: event,
        deliverable: deliverable,
        status: :pending,
        request_url: webhook.url,
        request_body: build_payload(event, deliverable, webhook)
      )

      Webhook::DeliveryJob.perform_later(delivery)
    end
  end

  private

  def build_payload(event, deliverable, webhook)
    Webhook::PayloadFormatter.new(
      event: event,
      deliverable: deliverable,
      webhook: webhook
    ).to_json
  end
end
```

```ruby
# app/jobs/webhook/delivery_job.rb
class Webhook::DeliveryJob < ApplicationJob
  queue_as :default

  def perform(delivery)
    tracker = Webhook::DelinquencyTracker.new(delivery.webhook)

    if tracker.delinquent?
      delivery.update!(status: :error, response_body: "Webhook paused due to failures")
      return
    end

    delivery.perform_request
    tracker.record_delivery_of(delivery)
  end
end
```

### triggered_by Scope

```ruby
# Query deliveries by event type
Webhook::Delivery.triggered_by("card.created")
Webhook::Delivery.triggered_by("comment.created")
```

---

## Testing Webhooks (PR #1196)

```ruby
# test/models/webhook/delivery_test.rb
class Webhook::DeliveryTest < ActiveSupport::TestCase
  include WebhookTestHelper

  setup do
    @webhook = webhooks(:active)
    @delivery = @webhook.deliveries.create!(
      event: "card.created",
      deliverable: cards(:one),
      status: :pending,
      request_url: @webhook.url,
      request_body: { card: { id: 1 } }.to_json
    )
  end

  test "successful delivery" do
    stub_request(:post, @webhook.url)
      .to_return(status: 200, body: "OK")

    @delivery.perform_request

    assert @delivery.delivered?
    assert_equal 200, @delivery.response_code
  end

  test "timeout sets timed_out status" do
    stub_request(:post, @webhook.url).to_timeout

    @delivery.perform_request

    assert @delivery.timed_out?
  end

  test "response too large is truncated" do
    large_body = "x" * 100.kilobytes
    stub_request(:post, @webhook.url)
      .to_return(status: 200, body: large_body)

    @delivery.perform_request

    assert @delivery.delivered?
    assert @delivery.response_body.bytesize <= Webhook::Delivery::MAX_RESPONSE_SIZE
  end

  test "DNS rebinding attack is prevented" do
    stub_dns_resolution(@webhook.url, "127.0.0.1")

    @delivery.perform_request

    assert @delivery.error?
    assert_includes @delivery.response_body, "private/internal addresses"
  end

  test "private IP addresses are rejected" do
    stub_dns_resolution(@webhook.url, "10.0.0.1")

    @delivery.perform_request

    assert @delivery.error?
  end

  test "signature is included in headers" do
    stub_request(:post, @webhook.url)
      .with { |request|
        request.headers["X-Webhook-Signature"].present? &&
        request.headers["X-Webhook-Timestamp"].present?
      }
      .to_return(status: 200)

    @delivery.perform_request
    assert @delivery.delivered?
  end
end
```

### stub_dns_resolution Helper

```ruby
# test/support/webhook_test_helper.rb
module WebhookTestHelper
  def stub_dns_resolution(url, ip_address)
    hostname = URI.parse(url).host
    Resolv.stub(:getaddress, ip_address) do
      yield if block_given?
    end

    # Alternative: stub at the delivery level
    Webhook::Delivery.any_instance.stubs(:resolve_ip).returns(ip_address)
  end
end
```

---

## Payload Formatting: Multi-Format Support (PR #1196)

Detect the webhook target service by URL pattern and format the payload accordingly:

```ruby
# app/models/webhook/payload_formatter.rb
class Webhook::PayloadFormatter
  SLACK_URL_PATTERN = /hooks\.slack\.com/
  CAMPFIRE_URL_PATTERN = /37signals\.com.*\/integrations\/.*\/channels/
  BASECAMP_URL_PATTERN = /3\.basecamp\.com.*\/integrations/

  attr_reader :event, :deliverable, :webhook

  def initialize(event:, deliverable:, webhook:)
    @event = event
    @deliverable = deliverable
    @webhook = webhook
  end

  def content_type
    case webhook.url
    when SLACK_URL_PATTERN    then "application/json"
    when CAMPFIRE_URL_PATTERN then "application/json"
    else "application/json"
    end
  end

  def to_json
    case webhook.url
    when SLACK_URL_PATTERN
      slack_payload.to_json
    when CAMPFIRE_URL_PATTERN
      campfire_payload.to_json
    when BASECAMP_URL_PATTERN
      basecamp_payload.to_json
    else
      default_payload.to_json
    end
  end

  private

  def default_payload
    {
      event: event,
      created_at: Time.current.iso8601,
      data: deliverable.as_json
    }
  end

  def slack_payload
    {
      text: summary_text,
      blocks: [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: convert_html_to_mrkdwn(summary_html)
          }
        }
      ]
    }
  end

  def campfire_payload
    { content: summary_text }
  end

  def basecamp_payload
    { content: summary_html }
  end

  def summary_text
    "#{deliverable.actor.name} #{event.humanize.downcase} in #{deliverable.bucket.name}"
  end

  def summary_html
    "<strong>#{deliverable.actor.name}</strong> #{event.humanize.downcase} " \
      "in <a href=\"#{deliverable_url}\">#{deliverable.bucket.name}</a>"
  end

  def deliverable_url
    Rails.application.routes.url_helpers.polymorphic_url(deliverable)
  end

  def convert_html_to_mrkdwn(html)
    html
      .gsub(/<strong>(.*?)<\/strong>/, '*\1*')
      .gsub(/<em>(.*?)<\/em>/, '_\1_')
      .gsub(/<a href="(.*?)">(.*?)<\/a>/, '<\1|\2>')
      .gsub(/<br\s*\/?>/, "\n")
      .gsub(/<\/?[^>]+>/, '')
  end
end
```

---

## Data Retention: Automatic Cleanup (PR #1292)

```ruby
# app/models/webhook/delivery.rb
class Webhook::Delivery < ApplicationRecord
  STALE_THRESHOLD = 7.days

  scope :stale, -> { where(created_at: ...STALE_THRESHOLD.ago) }
end
```

```ruby
# app/commands/webhook/purge_stale_deliveries_command.rb
# Using a command (not a class with .call) for consistency
class Webhook::PurgeStaleDeliveriesCommand
  def execute
    Webhook::Delivery.stale.in_batches(of: 1000).delete_all
  end
end
```

```yaml
# config/recurring.yml
webhook_cleanup:
  class: Webhook::PurgeStaleDeliveriesJob
  schedule: every day at 3am
  queue: default
```

```ruby
# app/jobs/webhook/purge_stale_deliveries_job.rb
class Webhook::PurgeStaleDeliveriesJob < ApplicationJob
  queue_as :default

  def perform
    Webhook::PurgeStaleDeliveriesCommand.new.execute
  end
end
```

Note: Uses a command separate from the job - the job is the scheduling mechanism, the command is the business logic. This allows the command to be run from console or tests without job infrastructure.

---

## Additional Insights

### Response Size Limiting

```ruby
MAX_RESPONSE_SIZE = 50.kilobytes

self.response_body = result.body&.truncate(MAX_RESPONSE_SIZE)
```

Prevents unbounded storage from large webhook responses.

### Timeout Configuration

```ruby
http.open_timeout = 5   # seconds to establish connection
http.read_timeout = 10  # seconds to wait for response
```

Short timeouts prevent webhook deliveries from blocking the job queue.

### URL Validation

```ruby
class Webhook < ApplicationRecord
  validates :url, presence: true, format: { with: /\Ahttps:\/\//i, message: "must use HTTPS" }
  validate :url_is_not_private

  private

  def url_is_not_private
    ip = Resolv.getaddress(URI.parse(url).host)
    if SsrfProtection::DISALLOWED_IP_RANGES.any? { |range| range.include?(IPAddr.new(ip)) }
      errors.add(:url, "cannot point to a private/internal address")
    end
  rescue Resolv::ResolvError
    errors.add(:url, "hostname could not be resolved")
  end
end
```

### User-Friendly Action Labels

```ruby
class Webhook < ApplicationRecord
  EVENTS = {
    "card.created"   => "When a card is created",
    "card.updated"   => "When a card is updated",
    "card.closed"    => "When a card is closed",
    "comment.created" => "When a comment is posted",
  }.freeze

  def self.event_options
    EVENTS.map { |value, label| [label, value] }
  end
end
```

### Event Granularity

Events are fine-grained (`card.created` not `card_changed`) so webhook consumers can subscribe to exactly what they need. The `events` column is a JSON array so a single webhook can listen to multiple event types.

---

## Summary: 10 Transferable Patterns

1. **SSRF Protection** - Resolve DNS upfront, validate against private IP ranges, pin IP for the request to prevent DNS rebinding.
2. **State Machine for Deliveries** - Track pending/delivered/failed/timed_out/error with full request/response logging.
3. **Delinquency Tracking** - Count consecutive failures; pause delivery after threshold (10 failures = 1 hour pause).
4. **HMAC-SHA256 Signatures** - Sign `timestamp.payload`, include both signature and timestamp headers.
5. **Two-Stage Job Pattern** - Dispatch job finds matching webhooks; Delivery job handles each individually.
6. **Multi-Format Payloads** - URL regex detection for Slack/Campfire/Basecamp; `convert_html_to_mrkdwn` for Slack.
7. **Response Size Limits** - Truncate stored responses to prevent database bloat.
8. **Short Timeouts** - 5s open / 10s read to prevent job queue blocking.
9. **Automatic Data Retention** - Purge deliveries older than 7 days via recurring job.
10. **URL Validation at Save Time** - HTTPS-only, DNS resolution check, private address rejection on create/update.
