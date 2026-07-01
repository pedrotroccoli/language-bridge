# Architecture

> **Status:** Implemented. Full Rails 8 application (server-rendered, not API-only).

## System Overview

![System Architecture](system-architecture.png)

## Stack

- **Ruby on Rails 8** — server-rendered with Hotwire (Turbo + Stimulus), Tailwind CSS v4
- **PostgreSQL** — UUIDv7 primary keys throughout
- **Solid Queue / Solid Cache** — database-backed jobs and cache (no Redis)
- **Active Storage** — delivery artifacts, project backups, user avatars (local or S3-compatible buckets via `StorageConnection`)
- **CDN-ready** — public delivery served with ETag + Cache-Control; artifacts stored gzip/brotli-compressed (`Content-Encoding`)

Single-tenant workspace: there is no Company/Account model. Global settings live in a single `Setting` row; users carry a `role` (admin / translator).

## Data Model

Core content hierarchy:

```
Project ─┬─ Namespace ── TranslationKey ─┐
         ├─ Locale ───────────────────────┴─ Translation
         └─ Translation::Artifact (materialized delivery file, one per namespace+locale)
```

A `Translation`'s lifecycle state is modelled as **records, not boolean columns** (37signals "state as records"):

- `Translation::Publication` — published (its presence = live); absence = draft
- `Translation::Review` — pending review request
- `Translation::Approval` — sign-off
- `Translation::Version` — prior-value history (snapshotted on value change)
- `Translation::Qa` — QA warning/fuzzy findings

Editing a value discards the publication and resets review/approval, then rebuilds the affected artifact.

Source: [`architecture.mmd`](architecture.mmd) → ![ERD](erd.png)

### Supporting models

| Area | Models |
|------|--------|
| **Auth** | `User`, `Session`, `SignInToken` (passwordless magic link via `generates_token_for`), `PersonalAccessToken` (`lb_pat_…`, SHA-256), `Invitation` |
| **API access** | `ApiToken` (per-project), `MissingKeyReport` (i18next saveMissing aggregation), CORS allow-list on `Setting` |
| **Delivery** | `Translation::Artifact` + `TranslationBundle` (compiles published keys into nested JSON), `DeliveryCompression` (gzip/brotli, brotli optional), `Project::Delivery` |
| **Backup / export** | `Project::Backup` (stored snapshot, Active Storage), `TranslationSnapshot` + `Snapshot::{JSON,CSV,XLIFF}` (serialization), `Project::Backups` |
| **Import** | `TranslationImport` (JSON/CSV/XLIFF → flattened dotted keys, bulk upsert) |
| **Machine translation** | `MachineTranslation` facade + pluggable provider (`StubProvider`) |
| **Storage** | `StorageConnection` (+ `Tester`), `Project::Storage`, `Project::Uploads` |
| **Settings** | `Setting` (single-row workspace defaults: rate limits, CORS origins, upload rules, delivery compression) |
| **Events** | `Event` (polymorphic audit log via the `Eventable` concern) |

`Project` composes behaviour through concerns: `Eventable`, `Storage`, `Backups`, `Delivery`, `Uploads`.

## API & Delivery

### Public i18n delivery (unauthenticated, CDN-cached)

```
GET /cdn/:project_slug/:locale/:namespace        # optional ".json" suffix
→ { "greeting": "Hello", "home": { "title": "Welcome" } }
```

Serves the materialized `Translation::Artifact` when present (streamed, compressed), else compiles live from `TranslationBundle`. ETag is the hash of the logical JSON, so it is compression-independent.

### Report missing keys (i18next saveMissing)

```
POST /api/v1/projects/:project_slug/missing
{ "locale": "en", "namespace": "common", "keys": { "new.key": "fallback value" } }
```

Private `/api/*` endpoints are origin-restricted (CORS allow-list in `Setting`); public `/cdn/*` is always open.

## Setup

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server
```
