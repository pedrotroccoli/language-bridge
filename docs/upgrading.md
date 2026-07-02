# Upgrading (Docker)

How to move a running instance to a newer app version. The whole app ships as one
image; upgrading is rebuild + recreate, and schema changes apply themselves.

## The one command

```bash
docker compose -f docker-compose.prod.yml up --build -d
```

That rebuilds the image (new code + new `db/migrate/*`), then recreates the
containers. The `pg-data` volume is **not** touched, so all data survives.

> **Never** add `-v`. `docker compose down -v` deletes the `pg-data` volume — a
> full data wipe. A normal upgrade never removes volumes.

## What happens on boot

1. **db** starts, healthcheck passes (existing data intact).
2. **migrate** runs `./bin/rails db:prepare` once and exits:
   - fresh database → creates the 4 Solid databases (primary/cache/queue/cable)
     and loads `schema.rb`;
   - existing database → runs only the **pending** migrations.
   `db:prepare` is idempotent, so re-running an already-migrated stack is a no-op.
3. **web** waits for `migrate` to finish successfully
   (`depends_on: service_completed_successfully`), then serves.

Only the `migrate` service migrates. `web` runs with `RUN_DB_PREPARE=false`, so
scaling or restarting web never triggers a concurrent migration — no races.

## Guarantees & limits

- **Forward migrations just work.** Commit each migration with its `schema.rb`
  and it applies on the next `up --build`.
- **A failed migration blocks the release.** If `migrate` exits non-zero, `web`
  will not start — the app stays down rather than booting against a half-migrated
  schema. **Test migrations before publishing the image.**
- **Not zero-downtime.** Recreating containers causes a short window where the app
  is unavailable. Acceptable for single-node; for true zero-downtime use the
  Kubernetes path (migrate Job + rolling `web`).
- **Backward-incompatible migrations can error during that window.** If a
  migration drops/renames a column the old code still reads, requests hit by the
  brief overlap fail. To avoid it, use the **expand/contract** pattern:
  1. Deploy A — add the new column/table; keep the old one; backfill.
  2. Deploy B — remove the old column once no code references it.
  Only needed if the downtime window matters to you.
- **Postgres major upgrades are manual.** Bumping `postgres:18` → a newer major
  does **not** auto-migrate the data directory; it needs `pg_upgrade`. Rails
  migrations do not cover this. Stay on one major unless you plan the upgrade.

## Rollback

Roll the image tag back and recreate. This only undoes **code**; it does not undo
migrations that already ran. Reversible migrations can be stepped back with
`docker compose -f docker-compose.prod.yml run --rm migrate ./bin/rails db:rollback`
before deploying the older image. Prefer forward-only, additive migrations so
rollback is just a code swap.
