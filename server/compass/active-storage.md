---
tags: [rails, 37signals, active-storage, uploads]
---

# Active Storage

> Preprocessing, upload expiry, avatar optimization.

See also: [[performance]], [[database]]

---

## Variant Preprocessing
```ruby
has_many_attached :embeds do |attachable|
  attachable.variant :small, resize_to_limit: [800, 600], preprocessed: true
end
```
Prevents failures on read replicas.

## Direct Upload Expiry
Extend to 48 hours for Cloudflare buffering.

## Large File Preview Limits
```ruby
def previewable?
  super && byte_size <= 16.megabytes
end
```

## Avatar Optimization
Redirect to blob URL instead of streaming through Rails.
```ruby
def show
  redirect_to rails_blob_url(@user.avatar.variant(:thumb))
end
```

## Mirror Configuration
Write to multiple backends (local + S3), read from primary.
```yaml
mirror:
  service: Mirror
  primary: local
  mirrors: [s3_backup]
```
