---
tags: [compass, rails, notifications, turbo]
see-also:
  - "[[email]]"
  - "[[background-jobs]]"
  - "[[hotwire]]"
---

# Notifications

## Read State Management with Timestamps (PR #208)

Use `read_at` timestamp instead of a boolean for richer querying:

```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true
  belongs_to :actor, class_name: "User", optional: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :newest_first, -> { order(created_at: :desc) }
  scope :for_card, ->(card) { where(notifiable: card) }

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read
    update!(read_at: Time.current) if unread?
  end

  def self.read_all
    unread.update_all(read_at: Time.current)
  end
end
```

Benefits over a boolean:
- Know **when** something was read (audit trail)
- Query "read in the last hour" for analytics
- `unread` scope is simply `where(read_at: nil)` - clean and indexable

---

## Notification Bundling with Time Windows (PR #974)

Bundle multiple notifications into a single digest to avoid overwhelming users:

```ruby
# app/models/notification/bundle.rb
class Notification::Bundle < ApplicationRecord
  belongs_to :user

  enum :status, { pending: 0, delivered: 1, skipped: 2 }

  scope :deliverable, -> {
    pending.where(deliver_after: ..Time.current)
  }

  scope :for_user, ->(user) { where(user: user) }

  # No FK to notifications - bundles aggregate by time window
  # Notifications belong to a bundle via time range overlap

  def notifications
    user.notifications.where(created_at: window_start..window_end)
  end

  def window_start
    created_at
  end

  def window_end
    created_at + user.settings.bundle_aggregation_period
  end

  validate :no_overlapping_bundles

  private

  def no_overlapping_bundles
    overlapping = self.class
      .for_user(user)
      .pending
      .where.not(id: id)
      .where("deliver_after > ? AND created_at < ?", window_start, window_end)

    if overlapping.exists?
      errors.add(:base, "overlaps with an existing pending bundle")
    end
  end
end
```

---

## User Preference Architecture with Settings Model (PR #974)

### User::Configurable Concern

```ruby
# app/models/concerns/user/configurable.rb
module User::Configurable
  extend ActiveSupport::Concern

  included do
    has_one :settings, class_name: "User::Settings", dependent: :destroy

    after_create :create_default_settings
  end

  def settings
    super || create_default_settings
  end

  private

  def create_default_settings
    create_settings!
  end
end
```

### User::Settings Model

```ruby
# app/models/user/settings.rb
class User::Settings < ApplicationRecord
  belongs_to :user

  enum :bundle_email_frequency, {
    immediately: 0,
    hourly: 1,
    daily: 2,
    weekly: 3,
    never: 4
  }, prefix: :email

  def bundle_aggregation_period
    case bundle_email_frequency
    when "immediately" then 0.minutes
    when "hourly"      then 1.hour
    when "daily"       then 1.day
    when "weekly"      then 1.week
    when "never"       then nil
    end
  end

  def wants_email_notifications?
    !email_never?
  end

  # Reactive: changing frequency reschedules pending bundles
  after_update :reschedule_pending_bundles, if: :saved_change_to_bundle_email_frequency?

  private

  def reschedule_pending_bundles
    user.notification_bundles.pending.find_each do |bundle|
      if wants_email_notifications?
        bundle.update!(deliver_after: bundle.created_at + bundle_aggregation_period)
      else
        bundle.skipped!
      end
    end
  end
end
```

---

## Automatic Bundling via Callbacks (PR #974)

### after_create :bundle

```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  after_create_commit :bundle

  private

  def bundle
    return unless user.settings.wants_email_notifications?

    user.find_or_create_bundle_for(self)
  end
end
```

### User::Notifiable Concern

```ruby
# app/models/concerns/user/notifiable.rb
module User::Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, dependent: :destroy
    has_many :notification_bundles,
      class_name: "Notification::Bundle",
      dependent: :destroy
  end

  def find_or_create_bundle_for(notification)
    period = settings.bundle_aggregation_period
    return deliver_immediately(notification) if period.zero?

    existing_bundle = notification_bundles
      .pending
      .where("created_at > ?", period.ago)
      .first

    if existing_bundle
      # Notification falls within existing bundle window
      existing_bundle
    else
      notification_bundles.create!(
        status: :pending,
        deliver_after: Time.current + period
      )
    end
  end

  private

  def deliver_immediately(notification)
    Notification::DeliverJob.perform_later(notification)
  end
end
```

---

## Background Job Pattern for Batch Delivery (PR #974)

### DeliverAllJob with Multi-Tenant Support

```ruby
# app/jobs/notification/deliver_all_job.rb
class Notification::DeliverAllJob < ApplicationJob
  queue_as :default

  def perform
    Account.find_each do |account|
      account.with do
        deliver_bundles_for_account
      end
    end
  end

  private

  def deliver_bundles_for_account
    Notification::Bundle.deliverable.find_each do |bundle|
      deliver_bundle(bundle)
    end
  end

  def deliver_bundle(bundle)
    notifications = bundle.notifications.unread

    if notifications.any?
      NotificationMailer.bundle(
        user: bundle.user,
        notifications: notifications
      ).deliver_now

      bundle.delivered!
    else
      bundle.skipped!
    end
  rescue => error
    Rails.logger.error("Failed to deliver bundle #{bundle.id}: #{error.message}")
  end
end
```

### perform_all_later and recurring.yml

```ruby
# For dispatching multiple jobs at once
Notification::DeliverJob.perform_all_later(
  notifications.map { |n| Notification::DeliverJob.new(n) }
)
```

```yaml
# config/recurring.yml
notification_delivery:
  class: Notification::DeliverAllJob
  schedule: every 5 minutes
  queue: default
```

---

## Turbo Streams for Real-Time Notification UI (PR #475)

### Broadcasting Read/Unread State

```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  after_update_commit :broadcast_read, if: :saved_change_to_read_at?

  def broadcast_unread
    broadcast_prepend_to(
      user, :notifications,
      target: "notifications",
      partial: "notifications/notification",
      locals: { notification: self }
    )

    broadcast_update_to(
      user, :notification_badge,
      target: "notification_badge",
      partial: "notifications/badge",
      locals: { count: user.notifications.unread.count }
    )
  end

  def broadcast_read
    broadcast_replace_to(
      user, :notifications,
      target: dom_id(self),
      partial: "notifications/notification",
      locals: { notification: self }
    )

    broadcast_update_to(
      user, :notification_badge,
      target: "notification_badge",
      partial: "notifications/badge",
      locals: { count: user.notifications.unread.count }
    )
  end
end
```

### View Setup

```erb
<%# app/views/notifications/index.html.erb %>
<%= turbo_stream_from current_user, :notifications %>
<%= turbo_stream_from current_user, :notification_badge %>

<div id="notification_badge">
  <%= render "notifications/badge", count: current_user.notifications.unread.count %>
</div>

<div id="notifications">
  <%= render partial: "notifications/notification",
    collection: @notifications %>
</div>
```

```erb
<%# app/views/notifications/_notification.html.erb %>
<%= turbo_frame_tag dom_id(notification) do %>
  <div class="notification <%= 'notification--unread' if notification.unread? %>">
    <p><%= notification.actor&.name %> <%= notification.action %></p>
    <time datetime="<%= notification.created_at.iso8601 %>">
      <%= time_ago_in_words(notification.created_at) %> ago
    </time>

    <% if notification.unread? %>
      <%= button_to "Mark read",
        notification_reading_path(notification),
        method: :post,
        class: "notification__mark-read" %>
    <% end %>
  </div>
<% end %>
```

---

## Pagination with Infinite Scroll via Intersection Observer (PR #208)

### fetch-on-visible Stimulus Controller

```javascript
// app/javascript/controllers/fetch_on_visible_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String
  }

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      { rootMargin: "100px" }
    )
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async handleIntersection(entries) {
    const entry = entries[0]
    if (!entry.isIntersecting) return

    this.observer.disconnect()

    const response = await fetch(this.urlValue, {
      headers: {
        Accept: "text/vnd.turbo-stream.html"
      }
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    }

    this.element.remove()
  }
}
```

### View Usage

```erb
<%# app/views/notifications/index.html.erb %>
<div id="notifications">
  <%= render partial: "notifications/notification",
    collection: @notifications %>
</div>

<% if @notifications.next_page %>
  <div data-controller="fetch-on-visible"
       data-fetch-on-visible-url-value="<%= notifications_path(page: @notifications.next_page, format: :turbo_stream) %>">
    <span class="loading-spinner" aria-label="Loading more notifications"></span>
  </div>
<% end %>
```

```ruby
# app/views/notifications/index.turbo_stream.erb
<%= turbo_stream.append "notifications" do %>
  <%= render partial: "notifications/notification",
    collection: @notifications %>
<% end %>

<% if @notifications.next_page %>
  <%= turbo_stream.append "notifications" do %>
    <div data-controller="fetch-on-visible"
         data-fetch-on-visible-url-value="<%= notifications_path(page: @notifications.next_page, format: :turbo_stream) %>">
      <span class="loading-spinner"></span>
    </div>
  <% end %>
<% end %>
```

---

## Client-Side Notification Grouping (PR #1448)

Group notifications by card on the client side to reduce visual noise:

```javascript
// app/javascript/controllers/notification_list_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["notification"]

  notificationTargetConnected(element) {
    this.groupNotifications()
  }

  groupNotifications() {
    const grouped = this.groupNotificationsByCardId()

    for (const [cardId, notifications] of Object.entries(grouped)) {
      if (notifications.length <= 1) continue

      const [primary, ...secondary] = notifications

      primary.classList.add("notification--group-primary")
      primary.dataset.groupCount = notifications.length

      const badge = primary.querySelector(".notification__group-badge") ||
        this.createBadge(primary)
      badge.textContent = `+${secondary.length} more`

      secondary.forEach(el => {
        el.classList.add("notification--grouped")
        el.hidden = true
      })
    }
  }

  groupNotificationsByCardId() {
    const groups = {}

    this.notificationTargets.forEach(el => {
      const cardId = el.dataset.cardId
      if (!cardId) return

      groups[cardId] = groups[cardId] || []
      groups[cardId].push(el)
    })

    return groups
  }

  createBadge(element) {
    const badge = document.createElement("span")
    badge.className = "notification__group-badge"
    element.querySelector(".notification__content")?.appendChild(badge)
    return badge
  }

  toggle(event) {
    const cardId = event.currentTarget.dataset.cardId
    const grouped = this.notificationTargets.filter(
      el => el.dataset.cardId === cardId && el.classList.contains("notification--grouped")
    )

    grouped.forEach(el => {
      el.hidden = !el.hidden
    })
  }
}
```

---

## RESTful Controller Design (PR #405)

Notification read state as a nested resource - `readings`:

```ruby
# config/routes.rb
resources :notifications, only: [:index, :show, :destroy] do
  resource :reading, only: [:create, :destroy], module: :notifications
end

namespace :notifications do
  resource :readings, only: [:create] # bulk read all
end
```

```ruby
# app/controllers/notifications/readings_controller.rb
class Notifications::ReadingsController < ApplicationController
  def create
    notification = current_user.notifications.find(params[:notification_id])
    notification.mark_as_read

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path }
      format.turbo_stream
    end
  end

  def destroy
    notification = current_user.notifications.find(params[:notification_id])
    notification.update!(read_at: nil)

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path }
      format.turbo_stream
    end
  end
end
```

```ruby
# app/controllers/notifications/readings_controller.rb (bulk)
# Note: separate controller in notifications namespace for bulk operation
class Notifications::ReadingsController < ApplicationController
  def create
    current_user.notifications.read_all

    respond_to do |format|
      format.html { redirect_to notifications_path, notice: "All marked as read" }
      format.turbo_stream
    end
  end
end
```

---

## Email Unsubscribe with Signed Tokens (PR #974)

### generates_token_for

```ruby
# app/models/user.rb
class User < ApplicationRecord
  generates_token_for :unsubscribe, expires_in: nil do
    settings.bundle_email_frequency
  end
end
```

The token embeds the current email frequency - if the user changes their preference, old unsubscribe links are automatically invalidated.

### List-Unsubscribe Headers

```ruby
# app/mailers/notification_mailer.rb
class NotificationMailer < ApplicationMailer
  def bundle(user:, notifications:)
    @user = user
    @notifications = notifications

    token = user.generate_token_for(:unsubscribe)

    headers["List-Unsubscribe"] = "<#{unsubscribe_url(token: token)}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail(
      to: user.email,
      subject: notification_subject(notifications)
    )
  end

  private

  def notification_subject(notifications)
    if notifications.size == 1
      notifications.first.summary
    else
      "#{notifications.size} new notifications"
    end
  end
end
```

### UnsubscribesController

```ruby
# app/controllers/unsubscribes_controller.rb
class UnsubscribesController < ApplicationController
  skip_before_action :authenticate

  def show
    @user = User.find_by_token_for(:unsubscribe, params[:token])

    if @user.nil?
      redirect_to root_path, alert: "Invalid or expired unsubscribe link"
    end
  end

  def create
    user = User.find_by_token_for!(:unsubscribe, params[:token])
    user.settings.update!(bundle_email_frequency: :never)

    redirect_to root_path, notice: "You have been unsubscribed from email notifications"
  end
end
```

---

## Email Layout with Inline Styles (PR #974)

### Table Layout for Email Compatibility

```erb
<%# app/views/layouts/mailer.html.erb %>
<!DOCTYPE html>
<html>
<head>
  <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
</head>
<body style="margin: 0; padding: 0; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5;">
    <tr>
      <td align="center" style="padding: 20px 0;">
        <table width="600" cellpadding="0" cellspacing="0"
               style="background-color: #ffffff; border-radius: 4px;">
          <tr>
            <td style="padding: 24px 32px;">
              <%= yield %>
            </td>
          </tr>
          <tr>
            <td style="padding: 16px 32px; color: #999; font-size: 12px; border-top: 1px solid #eee;">
              <p>You received this because of your notification settings.</p>
              <p><%= link_to "Unsubscribe", @unsubscribe_url,
                style: "color: #999; text-decoration: underline;" %></p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

### Group by Subject (PR #1574)

```erb
<%# app/views/notification_mailer/bundle.html.erb %>
<h2 style="margin: 0 0 16px; font-size: 18px; color: #333;">
  New notifications
</h2>

<% @notifications.group_by(&:notifiable).each do |subject, notifications| %>
  <table width="100%" cellpadding="0" cellspacing="0"
         style="margin-bottom: 16px; border: 1px solid #eee; border-radius: 4px;">
    <tr>
      <td style="padding: 12px 16px; background-color: #f9f9f9; font-weight: bold;">
        <%= subject.title %>
      </td>
    </tr>
    <% notifications.each do |notification| %>
      <tr>
        <td style="padding: 8px 16px; border-top: 1px solid #eee;">
          <p style="margin: 0;">
            <strong><%= notification.actor&.name %></strong>
            <%= notification.action %>
          </p>
          <p style="margin: 4px 0 0; color: #999; font-size: 12px;">
            <%= time_ago_in_words(notification.created_at) %> ago
          </p>
        </td>
      </tr>
    <% end %>
  </table>
<% end %>

<p style="text-align: center; margin: 24px 0 0;">
  <%= link_to "View all notifications", notifications_url,
    style: "display: inline-block; padding: 8px 16px; background-color: #0066cc; color: #fff; text-decoration: none; border-radius: 4px;" %>
</p>
```

---

## Testing Notification Delivery (PR #974)

### Time Travel Bundling Test

```ruby
class Notification::BundleTest < ActiveSupport::TestCase
  test "bundles notifications within time window" do
    user = users(:david)
    user.settings.update!(bundle_email_frequency: :hourly)

    # First notification creates a bundle
    notification1 = create_notification(user: user)
    bundle = user.notification_bundles.pending.last

    assert bundle.present?
    assert_equal "pending", bundle.status

    # Second notification within the hour joins existing bundle
    travel 30.minutes do
      notification2 = create_notification(user: user)

      assert_equal 1, user.notification_bundles.pending.count
      assert_includes bundle.notifications, notification1
      assert_includes bundle.notifications, notification2
    end

    # After the window, a new bundle is created
    travel 2.hours do
      notification3 = create_notification(user: user)

      assert_equal 2, user.notification_bundles.pending.count
    end
  end

  test "delivers bundle with unread notifications" do
    user = users(:david)
    user.settings.update!(bundle_email_frequency: :hourly)

    create_notification(user: user)
    bundle = user.notification_bundles.pending.last

    travel 1.hour do
      assert_emails 1 do
        Notification::DeliverAllJob.perform_now
      end

      assert bundle.reload.delivered?
    end
  end

  test "skips bundle when all notifications are read" do
    user = users(:david)
    user.settings.update!(bundle_email_frequency: :hourly)

    notification = create_notification(user: user)
    notification.mark_as_read
    bundle = user.notification_bundles.pending.last

    travel 1.hour do
      assert_no_emails do
        Notification::DeliverAllJob.perform_now
      end

      assert bundle.reload.skipped?
    end
  end

  private

  def create_notification(user:)
    user.notifications.create!(
      notifiable: cards(:one),
      action: "commented on",
      actor: users(:jason)
    )
  end
end
```

### Overlap Validation Test

```ruby
class Notification::BundleValidationTest < ActiveSupport::TestCase
  test "prevents overlapping pending bundles" do
    user = users(:david)

    bundle1 = Notification::Bundle.create!(
      user: user,
      status: :pending,
      deliver_after: 1.hour.from_now
    )

    bundle2 = Notification::Bundle.new(
      user: user,
      status: :pending,
      deliver_after: 30.minutes.from_now
    )

    assert_not bundle2.valid?
    assert_includes bundle2.errors[:base], "overlaps with an existing pending bundle"
  end

  test "allows bundles after previous one is delivered" do
    user = users(:david)

    bundle1 = Notification::Bundle.create!(
      user: user,
      status: :delivered,
      deliver_after: 1.hour.ago
    )

    bundle2 = Notification::Bundle.new(
      user: user,
      status: :pending,
      deliver_after: 1.hour.from_now
    )

    assert bundle2.valid?
  end
end
```

---

## Summary: Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Read tracking | `read_at` timestamp | Richer than boolean; enables "when read" queries |
| Bundling | Time-window model | No FK to notifications; flexible aggregation |
| User preferences | Dedicated Settings model | Single-table per user; enum for frequency |
| Bundle creation | `after_create` callback | Automatic; transparent to notification creators |
| Batch delivery | Recurring background job | Multi-tenant aware; every 5 minutes |
| Real-time UI | Turbo Streams broadcast | Server-pushed updates; no polling |
| Pagination | Intersection Observer | Infinite scroll without JavaScript frameworks |
| Client grouping | Stimulus controller | Group by card ID; collapse secondary items |
| Read/unread API | Nested `readings` resource | RESTful; single and bulk operations |
| Unsubscribe | `generates_token_for` | Self-invalidating on preference change |
| Email layout | Inline styles + tables | Maximum email client compatibility |
| Email grouping | Group by `notifiable` | One section per card/subject |
