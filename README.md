# Language Bridge

Open-source translation management system — a self-hosted, drop-in replacement
for Locize. This is a monorepo:

| Path       | What                                                                        |
|------------|-----------------------------------------------------------------------------|
| `server/`  | The Rails app: stores keys/translations, serves i18next JSON, web UI + API. |
| `cli/`     | `@language-bridge/cli` — pulls translations from a server and generates TypeScript types (the role locize-cli + `i18next-resources-for-ts` play for Locize). |

Deployment lives at the root: `config/deploy.yml` + `.kamal/` (Kamal), the
`docker-compose*.yml` stacks, and `k8s/`.

## Quick start

```sh
just server-dev   # run the Rails app (server/) on :3000
just cli-build    # build the CLI
just cli-test     # test the CLI
```

Without `just`, see the per-package READMEs: [`server/readme.md`](server/readme.md)
and [`cli/README.md`](cli/README.md).

## Generating types in a consumer app

```sh
npm i -D @language-bridge/cli
LB_TOKEN=lb_pat_… lb sync --project my-app --url https://your-server
```

This pulls the source locale and writes a typed `resources.d.ts` that augments
i18next so `t('ns:key')` is autocompleted and interpolation params are typed.
See [`cli/README.md`](cli/README.md).

## License

MIT
