# Delivery path templates (own bucket / CDN)

Materialized i18n artifacts are stored in the configured **Active Storage**
service under a **deterministic, human-readable object key** so you can point a
CDN origin straight at them in your own bucket.

## The template

Each project has a `delivery_path_template` (Project Settings → Public delivery).
It renders the storage key for every `(namespace, locale)` artifact. Tokens:

| Token | Example |
|-------|---------|
| `{project_slug}` | `main-app` |
| `{namespace}`    | `common` |
| `{locale}`       | `pt-BR` |

Default: `{project_slug}/{namespace}/{locale}.json` →
`main-app/common/pt-BR.json`.

Rules (validated): no leading `/`, only the tokens above, **must include
`{namespace}` and `{locale}`** (so each pair is unique), path-safe characters
only.

> **Multi-project instances:** keep `{project_slug}` in the template. Object keys
> share one bucket namespace; dropping `{project_slug}` lets two projects with the
> same namespace+locale collide on one key.

## Pointing at your own bucket

1. Configure an S3/GCS service in `config/storage.yml` and select it:
   `config.active_storage.service = :amazon` (per environment).
2. Set the template to the layout your CDN expects.
3. Point the CDN origin at the bucket. Objects land at the templated key
   (S3/GCS use the key verbatim). The Rails route `GET /cdn/:project/:locale/:namespace`
   keeps working regardless — the key change is storage-side only.

> The local **Disk** service sublards objects by a key prefix, so the on-disk path
> won't match the template literally. Predictable paths apply to S3/GCS.

## Changing the template

Saving a new template **re-materializes** all of the project's artifacts at the
new keys and **purges the blobs at the old keys**. On large instances this runs
on the request; moving it to a background job is tracked in #43.

A normal content edit keeps the same key and overwrites the object **in place**
(no key churn), so CDN URLs stay stable across translation edits.
