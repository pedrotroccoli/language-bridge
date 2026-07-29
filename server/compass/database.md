---
tags: [rails, 37signals, database, uuid, solid-stack]
---

# Database Patterns

> UUIDs, state as records, database-backed everything.

See also: [[models]], [[multi-tenancy]], [[performance]]

---

## UUIDs as Primary Keys (UUIDv7)
```ruby
create_table :cards, id: :uuid do |t|
  t.references :board, type: :uuid, foreign_key: true
end
```
- No ID guessing/enumeration. Safe for distributed systems. Client can generate IDs.

## State as Records — see [[models]]

## Database-Backed Infrastructure (no Redis)

### Solid Queue
```ruby
gem "solid_queue"
# config/database.yml — separate queue database
```

### Solid Cache
```ruby
gem "solid_cache"
config.cache_store = :solid_cache_store
```

### Solid Cable
```ruby
gem "solid_cable"
# config/cable.yml
production:
  adapter: solid_cable
```

## Account ID Everywhere
```ruby
validates :number, uniqueness: { scope: :account_id }
```

## No Soft Deletes
Hard delete records. Use events/audit logs for history.

## Counter Caches
```ruby
has_many :cards, counter_cache: true
```

## Index Strategy
```ruby
add_index :cards, :board_id
add_index :cards, [:account_id, :board_id, :created_at]
```

## Sharded Search (16 MySQL shards)
```ruby
def self.shard_for(account)
  :"shard_#{Zlib.crc32(account.id.to_s) % 16}"
end
```

## Key Principles
1. UUIDs over integers
2. State records over booleans
3. Database-backed infra over Redis
4. Hard deletes + audit logs
5. Counter caches for common counts
6. Index what you query
