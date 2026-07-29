---
tags: [rails, 37signals, models, concerns, activerecord]
---

# Models

> Rich domain models with composable concerns and state as records.

See also: [[philosophy]], [[dhh-patterns]], [[database]]

---

## Heavy Use of Concerns

```ruby
class Card < ApplicationRecord
  include Assignable, Attachments, Broadcastable, Closeable, Colored,
    Entropic, Eventable, Exportable, Golden, Mentions, Multistep,
    Pinnable, Postponable, Promptable, Readable, Searchable, Stallable,
    Statuses, Storage::Tracked, Taggable, Triageable, Watchable
end
```

## Concern Structure: Self-Contained

```ruby
module Card::Closeable
  extend ActiveSupport::Concern
  included do
    has_one :closure, dependent: :destroy
    scope :closed, -> { joins(:closure) }
    scope :open, -> { where.missing(:closure) }
  end

  def closed?
    closure.present?
  end

  def close(user: Current.user)
    unless closed?
      transaction do
        create_closure! user: user
        track_event :closed, creator: user
      end
    end
  end

  def reopen(user: Current.user)
    if closed?
      transaction do
        closure&.destroy
        track_event :reopened, creator: user
      end
    end
  end
end
```

## State as Records, Not Booleans

```ruby
# BAD
class Card < ApplicationRecord
  scope :closed, -> { where(closed: true) }
end

# GOOD
class Closure < ApplicationRecord
  belongs_to :card, touch: true
  belongs_to :user, optional: true
  # created_at = when, user = who
end

class Card < ApplicationRecord
  has_one :closure, dependent: :destroy
  scope :closed, -> { joins(:closure) }
  scope :open, -> { where.missing(:closure) }
end
```

### Real State Record Examples
- `Closure` — who/when closed a card
- `Card::Goldness` — marks as "golden"
- `Card::NotNow` — postponed
- `Board::Publication` — publicly published (has `has_secure_token :key`)

## Default Values via Lambdas

```ruby
belongs_to :account, default: -> { board.account }
belongs_to :creator, class_name: "User", default: -> { Current.user }
```

## Current for Request Context

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :identity, :account
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer
end
```

## Minimal Validations

```ruby
class Account < ApplicationRecord
  validates :name, presence: true  # That's it
end
```

Prefer DB constraints. Contextual validations: `validates :full_name, presence: true, on: :completion`

## Let It Crash (Bang Methods)

```ruby
@comment = @card.comments.create!(comment_params)
```

## Callbacks: Used Sparingly

Only 38 occurrences across 30 files. For setup/cleanup, NOT business logic.

## PORO Patterns

```ruby
# Presentation logic
class Event::Description
  def to_s
    case event.action
    when "created" then "#{creator_name} created this card"
    when "closed" then "#{creator_name} closed this card"
    end
  end
end

# View context bundling
class User::Filtering
  attr_reader :user, :filter, :expanded
  def boards; user.boards.accessible; end
  def assignees; user.account.users.active.alphabetically; end
end
```

POROs are model-adjacent, NOT service objects (controller-adjacent).

## Scope Naming

```ruby
# Good - business-focused
scope :active, -> { where.missing(:pop) }
scope :unassigned, -> { where.missing(:assignments) }

# Bad - SQL-ish
scope :without_pop, -> { ... }
```

### Common Patterns
```ruby
scope :alphabetically, -> { order(title: :asc) }
scope :recently_created, -> { order(created_at: :desc) }
scope :assigned_to, ->(user) { joins(:assignments).where(assignments: { user: user }) }
scope :tagged_with, ->(tag_ids) { joins(:taggings).where(taggings: { tag_id: tag_ids }) }
scope :preloaded, -> { includes(:creator, :board, :tags, :assignments, :closure) }
```

## Concern Organization

1. Each concern: **50-150 lines**
2. Must be **cohesive** — related functionality together
3. Don't create concerns just to reduce file size
4. Name for capability: `Closeable`, `Watchable`, `Assignable`

## Touch Chains for Cache Invalidation

```ruby
class Comment < ApplicationRecord
  has_one :message, as: :messageable, touch: true
end
class Message < ApplicationRecord
  belongs_to :bubble, touch: true
end
# comment → message → bubble cache invalidation
```
