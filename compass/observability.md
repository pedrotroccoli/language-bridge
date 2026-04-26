---
tags: [rails, 37signals, observability, logging, metrics]
---

# Observability

> Structured logging, Yabeda metrics, console auditing.

See also: [[configuration]], [[performance]]

---

## Structured JSON Logging
```ruby
config.log_level = :fatal
config.structured_logging.logger = ActiveSupport::Logger.new(STDOUT)
```

## Multi-Tenant Context
```ruby
before_action { logger.struct tenant: ApplicationRecord.current_tenant }
```

## User Context
```ruby
logger.struct "Authorized User##{session.user.id}",
  authentication: { user: { id: session.user.id } }
```

## Yabeda Metrics
```ruby
gem "yabeda", "yabeda-rails", "yabeda-puma-plugin", "yabeda-prometheus-mmap"
gem "yabeda-activejob", "yabeda-gc", "yabeda-http_requests", "yabeda-actioncable"
```

## Silence Health Checks
```ruby
config.silence_healthcheck_path = "/up"
```

## Console Auditing
```ruby
gem "console1984"
gem "audits1984"
config.console1984.protected_environments = %i[production staging]
```

## OpenTelemetry Collector as sidecar for container metrics
