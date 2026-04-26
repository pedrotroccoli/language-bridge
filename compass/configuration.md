---
tags: [compass, rails, configuration, kamal, deployment]
---

# Configuration

See also: [[security]], [[testing]]

## RAILS_MASTER_KEY Pattern

Every Rails app encrypts credentials with a master key. In production, this key is provided via the `RAILS_MASTER_KEY` environment variable. Never commit the master key to source control (#554).

With Kamal, secrets are managed through `.kamal/secrets`:

```bash
# .kamal/secrets
RAILS_MASTER_KEY=$(op read "op://AppVault/myapp/RAILS_MASTER_KEY")
```

```yaml
# config/deploy.yml
env:
  secret:
    - RAILS_MASTER_KEY
```

Kamal reads `.kamal/secrets` at deploy time, resolves the values (in this case from 1Password via `op read`), and injects them as environment variables in the container.

The pattern:
1. Store the actual key in a secrets manager (1Password, AWS SSM, Vault)
2. Reference it in `.kamal/secrets` using the appropriate CLI
3. Declare it in `deploy.yml` under `env.secret`
4. Rails reads `ENV["RAILS_MASTER_KEY"]` automatically

## YAML Configuration DRYness — Anchor References

YAML anchor references eliminate duplication across configuration files (#584).

### Before — Repetitive Configuration

```yaml
# config/database.yml
development:
  adapter: postgresql
  encoding: unicode
  pool: 5
  host: localhost
  database: myapp_development

test:
  adapter: postgresql
  encoding: unicode
  pool: 5
  host: localhost
  database: myapp_test
```

### After — DRY with Anchors

```yaml
# config/database.yml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: localhost

development:
  <<: *default
  database: myapp_development

test:
  <<: *default
  database: myapp_test

production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
```

The `&default` defines an anchor. The `<<: *default` merges all key-value pairs from the anchor into the current mapping. Individual keys can be overridden after the merge.

Apply this pattern to all YAML configuration files:

```yaml
# config/cable.yml
default: &default
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL", "redis://localhost:6379/1") %>

development:
  <<: *default

test:
  adapter: test

production:
  <<: *default
  url: <%= ENV["REDIS_URL"] %>
```

## Environment-Specific Configuration

Be explicit about `RAILS_ENV`. Don't rely on defaults or assume what environment you're running in.

### Environment Files Inherit from Production

For environments that are "production-like" (beta, staging), inherit from the production config rather than duplicating it:

```ruby
# config/environments/beta.rb
require_relative "production"

Rails.application.configure do
  # Only override what differs from production
  config.log_level = :debug
  config.action_mailer.default_url_options = { host: "beta.myapp.com" }
end
```

```ruby
# config/environments/staging.rb
require_relative "production"

Rails.application.configure do
  # Staging-specific overrides
  config.active_storage.service = :amazon_staging
  config.action_mailer.default_url_options = { host: "staging.myapp.com" }
end
```

This ensures beta and staging behave exactly like production except for the explicitly listed differences. No drift, no forgotten settings.

## Test Environment Handling

Avoid requiring credentials in the test environment. Tests should run without access to production secrets (#647).

```ruby
# BAD — tests fail without credentials file
class PaymentService
  def initialize
    @api_key = Rails.application.credentials.stripe[:api_key]
  end
end

# GOOD — fallback for test environment
class PaymentService
  def initialize
    @api_key = Rails.application.credentials.dig(:stripe, :api_key) || ENV["STRIPE_API_KEY"] || "test_key"
  end
end
```

```ruby
# BAD — initializer crashes in test
# config/initializers/stripe.rb
Stripe.api_key = Rails.application.credentials.stripe[:api_key]

# GOOD — skip in test or use safe dig
# config/initializers/stripe.rb
if Rails.application.credentials.dig(:stripe, :api_key)
  Stripe.api_key = Rails.application.credentials.stripe[:api_key]
end
```

The principle: a fresh clone of the repo should be able to run `bin/rails test` without any credentials file or environment variables.

## Environment Variable Precedence

Environment variables take priority over credentials. This allows runtime overrides without redeploying or re-encrypting credentials (#1976).

```ruby
# ENV takes priority over credentials
config.active_storage.service = ENV.fetch("STORAGE_SERVICE", Rails.application.credentials.dig(:storage, :service) || "local").to_sym
```

### Consistent Boolean ENV Vars

Establish a convention for boolean environment variables and stick to it:

```ruby
# Pick a convention and use it everywhere
def self.enabled?(key)
  ENV[key].present? && ENV[key] != "false" && ENV[key] != "0"
end

# Usage
if self.class.enabled?("FEATURE_NEW_DASHBOARD")
  # ...
end
```

```ruby
# Or use Rails' built-in ActiveModel::Type::Boolean
ActiveModel::Type::Boolean.new.cast(ENV["FEATURE_NEW_DASHBOARD"])
# "true", "1", "yes" => true
# "false", "0", "no", nil => false
```

## Development Environment Configuration

### Feature Flags in Development

Use environment variables for feature flags during development (#863):

```ruby
# config/environments/development.rb
Rails.application.configure do
  config.x.features.new_dashboard = ENV.fetch("FEATURE_NEW_DASHBOARD", "false") == "true"
  config.x.features.ai_assistant = ENV.fetch("FEATURE_AI_ASSISTANT", "false") == "true"
end
```

```ruby
# In views or controllers
if Rails.configuration.x.features.new_dashboard
  render "dashboards/new_show"
else
  render "dashboards/show"
end
```

### Development Scripts

Use `bin/` scripts for common development tasks:

```bash
#!/bin/bash
# bin/setup — idempotent setup script
set -e

echo "== Installing dependencies =="
bundle install
yarn install

echo "== Preparing database =="
bin/rails db:prepare

echo "== Removing old logs and tempfiles =="
bin/rails log:clear tmp:clear

echo "== Done! =="
```

### Smart Seed Data

Seed data should be idempotent and useful for development:

```ruby
# db/seeds.rb
identity = Identity.find_or_create_by!(email: "dev@example.com")
account = Account.find_or_create_by!(name: "Development")
User.find_or_create_by!(identity: identity, account: account) do |user|
  user.role = :admin
end

# Create realistic sample data
10.times do |i|
  project = account.projects.find_or_create_by!(name: "Project #{i + 1}") do |p|
    p.description = "Sample project for development"
  end

  5.times do |j|
    project.tasks.find_or_create_by!(title: "Task #{j + 1}") do |t|
      t.position = j
    end
  end
end
```

### Dynamic Dev Output

Enable verbose logging in development without polluting production:

```ruby
# config/environments/development.rb
Rails.application.configure do
  config.log_level = ENV.fetch("LOG_LEVEL", "debug").to_sym

  # Highlight SQL queries that take too long
  config.active_record.warn_on_records_fetched_greater_than = 500

  # Print deprecation notices
  config.active_support.deprecation = :log

  # Raise on missing translations
  config.i18n.raise_on_missing_translations = true
end
```

## Kamal Deployment Configuration

### Secrets Pattern

```bash
# .kamal/secrets
RAILS_MASTER_KEY=$(op read "op://AppVault/myapp/RAILS_MASTER_KEY")
DATABASE_URL=$(op read "op://AppVault/myapp/DATABASE_URL")
REDIS_URL=$(op read "op://AppVault/myapp/REDIS_URL")
```

### Environment-Specific Deploy Files

Use separate deploy files for different environments:

```yaml
# config/deploy.yml (production)
service: myapp
image: myapp/myapp

servers:
  web:
    hosts:
      - 192.168.1.1
      - 192.168.1.2
    labels:
      traefik.http.routers.myapp.rule: Host(`myapp.com`)

env:
  clear:
    RAILS_ENV: production
    RAILS_LOG_TO_STDOUT: true
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - REDIS_URL
```

```yaml
# config/deploy.staging.yml
service: myapp-staging
image: myapp/myapp

servers:
  web:
    hosts:
      - 192.168.2.1
    labels:
      traefik.http.routers.myapp-staging.rule: Host(`staging.myapp.com`)

env:
  clear:
    RAILS_ENV: staging
    RAILS_LOG_TO_STDOUT: true
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - REDIS_URL
```

Deploy with: `kamal deploy -d staging`

### Aliases

Define Kamal aliases for common operations:

```yaml
# config/deploy.yml
aliases:
  console: app exec --interactive bin/rails console
  logs: app logs -f
  dbconsole: app exec --interactive bin/rails dbconsole
  shell: app exec --interactive /bin/bash
```

Usage: `kamal console`, `kamal logs`, `kamal dbconsole`

## Configuration Organization Principles

1. **Secrets in a secrets manager, not in code.** Use `.kamal/secrets` to bridge between your secrets manager and the deployment environment. Never commit keys, tokens, or passwords.

2. **DRY your YAML with anchors.** Every YAML config file should use `&default` anchors to avoid repeating shared settings across environments.

3. **Environment files inherit, not duplicate.** Beta and staging should `require_relative "production"` and override only what differs. If you're copy-pasting a production config, you're doing it wrong.

4. **Tests run without credentials.** A fresh clone with no credentials file and no environment variables must be able to run the full test suite. Use safe `dig` with fallbacks.

5. **ENV overrides credentials.** Environment variables take priority over encrypted credentials, allowing runtime changes without redeployment.
