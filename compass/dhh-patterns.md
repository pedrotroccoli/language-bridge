---
tags: [rails, 37signals, dhh, code-review]
---

# DHH's Code Review Patterns

> Extracted from 100+ PR reviews in Fizzy. Focus: Simplicity, directness, Rails conventions, fighting abstraction.

See also: [[philosophy]], [[models]], [[views]], [[controllers]]

---

## Core: Earn Your Abstractions

- Question every layer of indirection: "Is this abstraction earning its keep?"
- If you can't point to 3+ variations that need it, inline it
- Methods and classes that don't explain anything should be removed ("anemic" code)
- Collapsed 6 notifier subclasses into 2

## Database Over Application Logic

```ruby
# Avoided
validates :code, uniqueness: true

# Preferred - database constraint
add_index :join_codes, :code, unique: true
```

When to validate: Only when you need user-facing error messages for form display.

## Naming Principles

```ruby
# Avoid negative names
scope :not_popped, -> { where(popped_at: nil) }
# Prefer positive
scope :active, -> { where(popped_at: nil) }
```

- `collect` implies returning an array — use `create_mentions` when you don't care about return value
- Consistent domain language throughout
- Method names should reflect their return value

## Be Explicit Over Clever

- When there are only 2-3 cases, explicit `case` statements beat metaprogramming
- Don't add base class extensions for one-off methods — put them on the specific class
- Define methods directly vs introspection

## StringInquirer for Action Predicates

```ruby
def action
  self[:action].inquiry
end
# event.action.completed? instead of event.action == "completed"
```

## Write-Time vs Read-Time Operations

```ruby
# Bad - computing at read time, can't paginate
def thread_entries
  (comments + events).sort_by(&:created_at)
end

# Good - delegated types, single-table query
class Message < ApplicationRecord
  delegated_type :messageable, types: %w[Comment EventSummary]
end
bubble.messages.order(:created_at).limit(20)
```

## View Patterns

- If a partial has virtually no HTML and is mostly Ruby logic → helper or model method
- Helpers should receive explicit parameters, not rely on magical ivars:
```ruby
# Bad
def bubble_activity_count
  @bubble.comments_count + @bubble.events_count
end
# Good
def bubble_activity_count(bubble)
  bubble.comments_count + bubble.events_count
end
```
- Double-indent attributes in tag helpers
- Use tag helpers for meta tags with interpolation
- Turbo Stream canonical style: `turbo_stream.update [ @card, :new_comment ]`

## Caching Principles

- Use `touch: true` on associations rather than complex cache key dependencies
- Use `update_all` for bulk updates when no side effects needed
- Don't like base page cache dependent on anything beyond itself

## API Design

- Don't need `respond_to` block when templates exist for both formats
- Inline Jbuilder: `json.steps @card.steps, partial: "steps/step", as: :step`
- Prefer `head :no_content` for updates
- Use `My::` namespace for Current user resources

## Rails Conventions

- Use `after_save_commit` instead of `after_commit on: %i[ create update ]`
- Use `pluck(:name)` instead of `map(&:name)`
- Delegate for lazy loading: `delegate :user, to: :session`
- Touch chains for cache invalidation

## Testing

- Avoid test-induced design damage
- Migrations can reference models — they were only ever meant to be transient

## Key Takeaways

1. **Abstractions must earn their keep** — inline if no variations
2. **Write time > Read time** — compute when saving, not presenting
3. **Database over AR** — prefer DB constraints
4. **Positive names** — `active` not `not_deleted`
5. **Explicit over clever** — case statements for 2-3 variations
6. **Touch chains** — `touch: true` for cache invalidation
7. **Helpers take params** — don't rely on magical ivars
8. **Tests shouldn't shape design** — never add code just for testability
