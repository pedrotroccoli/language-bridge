---
tags: [rails, 37signals, watching, subscriptions]
---

# Watching

> Involvement enum on access records, not separate subscriptions.

See also: [[notifications]], [[actioncable]], [[models]]

---

## Embed in Access Records
```ruby
class Access < ApplicationRecord
  enum :involvement, %i[ access_only watching ]
end
```
No separate `Subscription` model.

## Binary is Best
"Watching" vs "Not Watching" — clearer than 3+ levels.

## Collection vs Resource Watching
- **Collection** (boards): notify of NEW items
- **Resource** (cards): notify of UPDATES to this item

```ruby
module Card::Watchable
  included do
    has_many :watches, dependent: :destroy
    has_many :watchers, -> { active.merge(Watch.watching) }, through: :watches, source: :user
    after_create -> { watch_by creator }
  end
end
```

## Clean Up on Access Removal
When access revoked, destroy watches, notifications, mentions.

## Toggle UI with Turbo Streams
Update multiple parts in one response (button + watchers list).

## Always Notify for @mentions and assignments regardless of involvement level.
