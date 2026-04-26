---
tags: [rails, 37signals, jorge-manrubia, architecture]
---

# Jorge Manrubia — Architecture & Rails Patterns

> Focus: Architecture, Rails patterns, testing, and performance. Style: questions and suggestions, not mandates.

See also: [[philosophy]], [[dhh-patterns]], [[performance]], [[caching]]

---

## Narrow Public APIs

- Only expose what's actually used
- "The narrower the public surface of a class the better"
- Don't add public methods that aren't used anywhere

```ruby
# Bad - exposes internals
class Quota
  def reset_quota; end
  def check_if_due_for_reset; end
  def calculate_usage; end
end

# Good - narrow public API
class Quota
  def spend(cost); end
  def ensure_not_depleted; end
  private
    def reset_if_due; end
    def depleted?; end
end
```

## Domain-Driven Naming

```ruby
quota.spend(cost)           # not increment_usage(cost)
quota.ensure_not_depleted   # not ensure_under_limit
quota.depleted?             # not over_limit?
# "A quota is something you spend until you don't have anything left"
```

## Objects Emerge from Coupling

When parameters get passed through multiple method layers, extract an object.

```ruby
# Smell: shared param coupling
def cost(within:); end
def cost_microcents(within:); end
def limit_cost(within:); end

# Solution: extract Ai::Quota model
class Ai::Quota < ApplicationRecord
  def spend(cost); end
  def ensure_not_depleted; end
end
```

## Concerns: Public Behavior Only

```ruby
# Bad - concern with only private methods
module Ai::Quota::Resettable
  private
    def reset_if_due; end
end

# Good - inline private methods in main class
class Ai::Quota
  private
    def reset_if_due; end
end
```

Rule: Concerns = auxiliary public traits (Attachable, Named). Private methods = inline.

## Memoize Hot Paths

```ruby
def as_params
  @as_params ||= {}.tap do |params|
    params[:indexed_by] = indexed_by
  end
end
```

"This method is invoked many times during page rendering and triggers many queries."

## Layer Caching

- HTTP cache (`fresh_when`) — full response
- Column cache — shared across users with same events
- Filter menu — per-user, reused across pages
- Timezone in etag for user-specific rendering

## Fixed-Point for Money

```ruby
class Ai::Quota::Money < Data.define(:value)
  MICROCENTS_PER_DOLLAR = 100 * 1_000_000

  def self.convert_dollars_to_microcents(dollars)
    (dollars.to_d * MICROCENTS_PER_DOLLAR).round.to_i
  end

  def in_dollars
    value.to_d / MICROCENTS_PER_DOLLAR
  end
end
```

Why microcents? LLM costs are fractions of a cent. SQLite DECIMAL is backed by float.

## Time-Based Reset Without Cron

```ruby
def spend(cost)
  transaction do
    reset_if_due
    increment!(:used, cost.in_microcents)
  end
end

private
  def reset_if_due
    reset if due_for_reset?
  end
```

"We can get by without the Cron job by checking when it's incremented."

## VCR for External APIs

```ruby
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data('<API_KEY>') { Rails.application.credentials.openai.api_key }
end
```

To update: `VCR_RECORD=1 bin/rails test`

## Custom Types: Only When Justified

If money conversion only happens in one place, a value object is enough. Custom Active Model types only when spread across many models.

## Error Handling: Specific Errors

```ruby
class Ai::Quota::UsageExceedsQuotaError < StandardError; end

def ensure_not_depleted
  raise UsageExceedsQuotaError if depleted?
end

# Controller
rescue_from Ai::Quota::UsageExceedsQuotaError do
  render json: { error: "You've depleted your quota" }, status: :too_many_requests
end
```

## Key Takeaways

1. **Narrow public APIs** — only expose what's used
2. **Domain names** — `depleted?` not `over_limit?`
3. **Objects from coupling** — shared params → extract object
4. **Memoize hot paths** — methods called during rendering
5. **Layer caching** — HTTP, templates, queries
6. **Fixed-point money** — integers, not floats
7. **Reset on use** — simpler than cron
8. **VCR for APIs** — fast, deterministic tests
9. **Teach through questions** — "What do you think of..." not "Change this to..."
