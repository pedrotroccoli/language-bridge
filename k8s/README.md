# Kubernetes deployment

Provider-neutral plain manifests. Bring your own cluster, ingress controller, and
**external PostgreSQL** (managed Postgres, or one you run separately). The app is
12-factor: everything is configured through env vars in `configmap.yaml` +
`secret.yaml`.

## Two steps

**1. Configure**

```sh
# Secrets — copy the template, generate values, fill it in
cp secret.example.yaml secret.yaml
bin/rails secret              # -> SECRET_KEY_BASE
bin/rails db:encryption:init  # -> the three AR_ENCRYPTION_* keys
$EDITOR secret.yaml           # paste values (also BACK_DATABASE_PASSWORD, SMTP, S3)

# Non-secret config — set DB_HOST, APP_HOST/RAILS_HOSTS, storage, image, ...
$EDITOR configmap.yaml
```

The manifests point at `belzkai/language-bridge:0.0.1` (published on Docker Hub).
Change that image tag in `migrate-job.yaml`, `web-deployment.yaml`, and
`jobs-deployment.yaml` if you publish under a different repo.

**2. Deploy**

```sh
kubectl apply -f secret.yaml -f configmap.yaml
kubectl apply -f .        # migrate Job + web + jobs + service (+ ingress/hpa)
```

The `migrate` Job creates the 4 databases (primary + Solid cache/queue/cable) and
runs migrations. Web/job pods wait on it via an initContainer, so no replica ever
races to migrate. Then apply `ingress.example.yaml` (edit host/TLS first).

## What each file is

| File | Purpose |
|------|---------|
| `secret.example.yaml` | Template for secret env vars → copy to `secret.yaml` |
| `configmap.yaml` | Non-secret env vars (DB host, storage, hosts, SMTP) |
| `migrate-job.yaml` | One-shot `db:prepare` (create DBs + migrate) |
| `web-deployment.yaml` | Puma + Thruster, `/up` probes, waits for migrations |
| `web-service.yaml` | ClusterIP for the web pods |
| `jobs-deployment.yaml` | Solid Queue workers (`bin/jobs`) — optional |
| `ingress.example.yaml` | Host + TLS termination (edit for your controller) |
| `hpa.yaml` | Optional CPU autoscaling (needs metrics-server) |
| `pvc.yaml` | Only for `ACTIVE_STORAGE_SERVICE=local` (prefer S3/GCS) |

## Storage (important for >1 replica)

Active Storage holds app blobs (imports/exports, backups) on local disk at
`/rails/storage`. The web and jobs pods mount the shared `pvc.yaml` claim there.
Because that path is per-pod, the claim must be **ReadWriteMany** when more than
one pod writes to it — use an RWX storage class (NFS, EFS, Filestore, Longhorn).
If only ReadWriteOnce is available, keep web `replicas: 1` and disable the HPA.

Cloud **delivery/storage targets** (S3/GCS/Azure per project) are configured at
runtime in the app UI (StorageConnection), not through these manifests.

## Jobs: two shapes

- **Dedicated workers (default here):** `SOLID_QUEUE_IN_PUMA=false` +
  `jobs-deployment.yaml`. Scale web and jobs independently.
- **Simplest:** set `SOLID_QUEUE_IN_PUMA=true` in `configmap.yaml` and delete
  `jobs-deployment.yaml` — web pods run jobs in-process.

## Database

`config/database.yml` connects the production primary as role **`back`** using
`BACK_DATABASE_PASSWORD`, at `DB_HOST:DB_PORT`. That role needs privileges to
`CREATE DATABASE` (the Job creates `back_production`, `_cache`, `_queue`,
`_cable`). Grant `CREATEDB` or run the Job once with a superuser, then downgrade.
