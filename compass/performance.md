---
tags: [rails, 37signals, performance, n-plus-1, puma]
---

# Performance

> Database, CSS, rendering optimizations.

See also: [[caching]], [[database]], [[hotwire]]

---

## CSS: Avoid complex `:has()` (Safari freezes)
## Database: N+1 → JOINs, accept SQL when performance requires
## Pagination: 25-50, "Load more" buttons
## Debouncing: 100ms on filter search
## Puma/Ruby:
```ruby
workers Concurrent.physical_processor_count
threads 1, 1
before_fork { Process.warmup }  # GC, compact, malloc_trim
```
Use `autotuner` gem for suggestions.

## N+1 Prevention
```ruby
# Bad - extra query
assignments.exists? assignee: user
# Good - in-memory
assignments.any? { |a| a.assignee_id == user.id }
```

## Preloaded Scopes
```ruby
scope :preloaded, -> { includes(:column, :tags, board: [:entropy, :columns]) }
```

## Active Storage
- `preprocessed: true` for variants
- Extend signed URL expiry to 48h (Cloudflare)
- Skip previews > 16MB
- Redirect to blob URL for avatars

## Optimistic UI for D&D
Insert immediately, POST async. Let server re-render.

## Batch SQL Over Loops
```ruby
user.mentions
  .joins("LEFT JOIN cards ON ...")
  .where("cards.collection_id = ?", id)
  .destroy_all
```
