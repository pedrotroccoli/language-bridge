---
tags: [rails, 37signals, background-jobs, solid-queue]
---

# Background Jobs

> Solid Queue. Shallow jobs. Transaction safety.

See also: [[database]], [[email]], [[webhooks]]

---

## Configuration
- Dev: `SOLID_QUEUE_IN_PUMA=1` (no separate process)
- Prod: workers = CPU cores, 3 threads for I/O
- Stagger recurring jobs to prevent spikes

## Transaction Safety
```ruby
ActiveJob::Base.enqueue_after_transaction_commit = true
```
Prevents jobs from running before data exists.

## Error Handling

### Transient — retry with backoff
```ruby
retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer
retry_on Net::SMTPServerBusy, wait: :polynomially_longer
```

### Permanent — swallow, log at info
```ruby
rescue_from Net::SMTPFatalError do |error|
  case error.message
  when /\A550 5\.1\.1/, /\A552 5\.6\.0/
    Sentry.capture_exception error, level: :info
  else
    raise
  end
end
```

## Shallow Jobs
```ruby
class NotifyRecipientsJob < ApplicationJob
  def perform(notifiable)
    notifiable.notify_recipients
  end
end
```

## `_later` / `_now` Convention
```ruby
def notify_recipients       # sync - actual work
  Notifier.for(self)&.notify
end
private
  def notify_recipients_later # async - enqueue
    NotifyRecipientsJob.perform_later(self)
  end
```

## Continuable Jobs
```ruby
include ActiveJob::Continuable
def perform(event)
  step :dispatch do |step|
    Webhook.active.find_each(start: step.cursor) do |webhook|
      webhook.trigger(event)
      step.advance! from: webhook.id
    end
  end
end
```
Resumes from where it left off after crashes.

## Maintenance
- Clean finished jobs (hourly): `SolidQueue::Job.clear_finished_in_batches`
- Clean orphaned data: unused tags, old webhook deliveries, expired magic links
