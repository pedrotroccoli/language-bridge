# CDN setup

The public delivery endpoint is built to sit behind a CDN. The CDN absorbs read
traffic; the Rails origin only serves cache misses and revalidations.

```
i18n client ──▶ CDN (edge cache) ──▶ Rails origin  GET /cdn/:slug/:locale/:ns(.json)
                     │                      │
                  by URL path        Translation::Artifact (Active Storage blob)
                                            └─ falls back to compiling live
```

## Origin contract

`DeliveryController` already emits everything a CDN needs:

| Header | Value | Purpose |
|--------|-------|---------|
| `Cache-Control` | `public, max-age=3600, stale-while-revalidate=300` | cache 1h at the edge; serve stale up to 5 min while revalidating |
| `ETag` | content fingerprint (`Translation::Artifact#checksum`) | change detection |
| `304 Not Modified` | on matching `If-None-Match` | cheap revalidation, empty body |

The `ETag` is derived from the compiled content, so it changes the instant a
translation is published, unpublished, edited, or deleted. A client (or CDN)
holding a stale copy gets a new body on its next revalidation.

## Cloudflare configuration

Cache rule (or legacy Page Rule) matching the delivery path:

- **Match:** `*/cdn/*`
- **Cache eligibility:** Eligible for cache
- **Edge TTL:** *Use cache-control header from origin* (honors `max-age=3600`)
- **Browser TTL:** Respect origin
- **Cache key:** URL path (no cookies, no query — the endpoint takes none)
- Leave **Respect strong ETags** / origin revalidation on, so `If-None-Match`
  is forwarded and `304`s are honored.

No Worker is required for caching. `stale-while-revalidate` is honored natively.

## Cache invalidation on publish

Two layers, in order of preference:

1. **Automatic (no action needed).** `stale-while-revalidate=300` means a publish
   propagates within ~5 minutes everywhere, with no purge call. For most content
   this is enough.

2. **Instant purge (optional).** For zero-delay propagation, purge the specific
   URL when a `Translation::Publication` is created or its artifact is rebuilt.
   The targeted path is deterministic:

   ```
   https://<delivery-host>/cdn/<project-slug>/<locale-code>/<namespace-name>.json
   ```

   Cloudflare purge-by-URL:

   ```bash
   curl -X POST \
     "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
     -H "Authorization: Bearer $CF_API_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"files":["https://cdn.example.com/cdn/demo-app/en/common.json"]}'
   ```

   The natural trigger is `Translation::Artifact.rebuild` — it runs on exactly
   the content changes that need a purge. Wiring this as an outbound call belongs
   with the webhook/delivery-job work (#43): it needs retries, timeouts, and to
   run off the request path, plus the `CF_ZONE_ID` / `CF_API_TOKEN` secrets. Until
   then, layer 1 covers propagation.

## Local / development

No CDN. Requests hit Rails directly; the same `Cache-Control`/`ETag` headers
apply, so behavior matches production minus the edge cache.
