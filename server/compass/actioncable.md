---
tags: [rails, 37signals, actioncable, websockets, solid-cable]
---

# ActionCable

> Multi-tenant WebSockets, scoped broadcasts, Solid Cable.

See also: [[multi-tenancy]], [[hotwire]], [[notifications]]

---

## Multi-Tenant Authentication
- Set tenant context during connection
- Validate session AND tenant membership
- Reject if either fails

## Account-Scoped Broadcasts (CRITICAL)
```ruby
# WRONG - DoS yourself across all tenants!
<%= turbo_stream_from :all_boards %>
# CORRECT
<%= turbo_stream_from [ Current.account, :all_boards ] %>
```

## Dual Broadcasting
```ruby
broadcasts_refreshes
broadcasts_refreshes_to ->(board) { [ board.account, :all_boards ] }
```

## Forcibly Disconnect Users
```ruby
ActionCable.server.remote_connections.where(current_user: self).disconnect(reconnect: false)
```

## Individual vs Batch
Don't `update_all` when broadcasts needed — iterate with `.each`.

## Solid Cable
```yaml
production:
  adapter: solid_cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

## Use `broadcast_*_later` for async broadcasting

## Selective Subscriptions
Only subscribe to visible data:
```erb
<% if filter.collections.any? %>
  <% filter.collections.each do |c| %><%= turbo_stream_from c %><% end %>
<% else %>
  <%= turbo_stream_from [ Current.account, :all_collections ] %>
<% end %>
```

## Testing
```ruby
assert_turbo_stream_broadcasts([ notification.user, :notifications ], count: 1) do
  notification.unread
end
```
