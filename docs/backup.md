# Cloud backups (translations)

Language Bridge periodically snapshots every project's translations to the
configured **Active Storage** service — your own S3/GCS bucket when configured,
local Disk otherwise. A backup is a single, self-contained JSON document: every
namespace, key, locale, value and published state. It is restorable on its own
(no database dump needed).

## What a backup contains

```json
{
  "version": 1,
  "created_at": "2026-06-28T03:00:00Z",
  "project": { "slug": "main-app", "name": "Main App" },
  "locales": ["en", "pt-BR", "es"],
  "namespaces": {
    "common": {
      "common.welcome": {
        "en":    { "value": "Welcome",   "published": true },
        "pt-BR": { "value": "Bem-vindo", "published": false }
      }
    }
  }
}
```

Stored at a readable key in the service:
`backups/{project_slug}/{YYYYMMDD-HHMMSS}-{id}.json`.

## Scheduling

A recurring Solid Queue job snapshots **all projects daily** — see
`config/recurring.yml`:

```yaml
backup_translations:
  class: BackupAllProjectsJob
  schedule: every day at 3am
```

`BackupAllProjectsJob` fans out one `BackupProjectJob` per project. Each writes a
snapshot blob and prunes older backups beyond the retention limit
(`BACKUP_KEEP`, default 30). Point Active Storage at a cloud bucket to get
off-box, durable backups automatically.

> Recurring jobs run wherever the Solid Queue supervisor runs (e.g. Puma with
> `SOLID_QUEUE_IN_PUMA=1`, or a dedicated worker).

## Manual backup, download, restore

Project Settings → **Cloud backups**:

- **Back up now** — creates a snapshot immediately.
- **Download** — the raw JSON blob.
- **Restore** — re-imports a snapshot: creates any missing locales/namespaces/keys
  and upserts values (re-publishing where the snapshot was published). Restore is
  an **upsert** — it never deletes keys or translations that aren't in the
  snapshot.

## Notes

- Backups contain translation content (and could contain sensitive strings). The
  bucket inherits whatever access controls you set on the Active Storage service;
  treat it accordingly.
- Snapshots are deterministic — re-running a backup with no changes produces the
  same content (matching `checksum`).
