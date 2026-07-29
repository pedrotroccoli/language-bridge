# Language Bridge

Open-source translation management system — a self-hosted, drop-in replacement
for Locize. This is a monorepo:

| Path       | What                                                                        |
|------------|-----------------------------------------------------------------------------|
| `server/`  | The Rails app: stores keys/translations, serves i18next JSON, web UI + API. |
| `cli/`     | Reserved for `@language-bridge/cli` — a type generator that pulls translations from a server and emits TypeScript types. Not implemented yet (empty placeholder). |

Deployment lives at the root: `config/deploy.yml` + `.kamal/` (Kamal), the
`docker-compose*.yml` stacks, and `k8s/`.

## Quick start

```sh
just server-dev     # run the Rails app (server/) on :3000
```

Without `just`, see [`server/readme.md`](server/readme.md).

## License

MIT
