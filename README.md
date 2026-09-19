# Language Bridge

Open-source, self-hosted translation management for i18next. Store keys, let
translators fill in values, and serve CDN-cached JSON with no frontend redeploy —
on your own infrastructure, no per-seat pricing. This is a monorepo:

| Path       | What                                                                        |
|------------|-----------------------------------------------------------------------------|
| `server/`  | The app: stores keys/translations, serves i18next JSON, web UI + API. |
| `cli/`     | `@language-bridge/cli` — pulls translations from a server and generates typed i18next resources (`resources.d.ts`). |

Deployment lives at the root: `config/deploy.yml` + `.kamal/` (Kamal), the
`docker-compose*.yml` stacks, and `k8s/`.

## Documentation

Full docs: **https://pedrotroccoli.github.io/language-bridge/docs**

The docs site lives in [`docs/`](docs/) and is deployed to GitHub Pages on every
push to `main`.

## Quick start

```sh
just server-dev   # run the app (server/) on :3000
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
