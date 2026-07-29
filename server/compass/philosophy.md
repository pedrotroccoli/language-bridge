---
tags: [rails, 37signals, philosophy]
---

# Development Philosophy

> Core principles observed across 265 PRs in Fizzy.

See also: [[dhh-patterns]], [[jorge-manrubia]], [[jason-zimdars]], [[what-they-avoid]]

---

## Ship, Validate, Refine

- Merge "prototype quality" code to validate with real usage before cleanup
- Features evolve through iterations (tenanting: 3 attempts before settling)
- Don't polish prematurely - real-world usage reveals what matters

## Fix Root Causes, Not Symptoms

**Bad**: Add retry logic for race conditions
**Good**: Use `enqueue_after_transaction_commit` to prevent the race

**Bad**: Work around CSRF issues on cached pages
**Good**: Don't HTTP cache pages with forms

## Vanilla Rails Over Abstractions

- Thin controllers calling rich domain models
- No service objects unless truly justified
- Direct ActiveRecord is fine: `@card.comments.create!(params)`
- When services exist, they're just POROs: `Signup.new(email:).create_identity`

## When to Extract

- Start in controller, extract when it gets messy
- Filter logic: controller → model concern → dedicated PORO
- Don't extract prematurely — wait for pain
- Rule of three: duplicate twice before abstracting

## Write-Time vs Read-Time Operations

All manipulation should happen when you save, not when you present:
- Use delegated types for heterogeneous collections needing pagination
- Pre-compute roll-ups at write time
- Use `dependent: :delete_all` when no callbacks needed
- Use counter caches instead of manual counting

```ruby
# Bad - computing at read time
def thread_entries
  (comments + events).sort_by(&:created_at)
end

# Good - using delegated types with single-table query
class Message < ApplicationRecord
  delegated_type :messageable, types: %w[Comment EventSummary]
end
bubble.messages.order(:created_at).limit(20)
```

## Common Review Themes

- **Naming**: Use positive names (`active` not `not_deleted`, `unpopped`)
- **DB over AR**: Prefer database constraints over ActiveRecord validations
- **Migrations**: Use SQL, avoid model references that break future runs
- **Simplify**: Links over JavaScript when browser affordances suffice

## StringInquirer for Action Predicates

```ruby
def action
  self[:action].inquiry
end
# Usage: event.action.completed?
```

## Caching Constraints Inform Architecture

Design caching early — it reveals architectural issues:
- Can't use `Current.user` in cached partials
- Solution: Push user-specific logic to Stimulus controllers reading from meta tags
- Leave FIXME comments when you discover caching conflicts

## Rails Patterns

### Delegated Types for Polymorphism
```ruby
class Message < ApplicationRecord
  delegated_type :messageable, types: %w[Comment EventSummary],
                 inverse_of: :message, dependent: :destroy
end
```

### Store Accessor for JSON Columns
```ruby
store_accessor :filters, :order_by, :status, :assignee_ids
validates :order_by, inclusion: { in: ORDERS.keys, allow_nil: true }
```

### Normalizes for Data Consistency (Rails 7.1+)
```ruby
normalizes :subscribed_actions,
  with: ->(value) { Array.wrap(value).map(&:to_s).uniq & PERMITTED_ACTIONS }
```

### params.expect (Rails 7.1+)
```ruby
# Before
params.require(:user).permit(:name, :email)
# After
params.expect(user: [:name, :email])
```
