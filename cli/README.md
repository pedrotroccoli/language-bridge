# @language-bridge/cli

Pull translations from a [Language Bridge](../README.md) server and generate
typed i18next resources — the role `locize-cli` + `i18next-resources-for-ts` play
for Locize, in one first-party tool.

Two layers of typing:

- **Keys** — a `Resources` interface that augments i18next's `CustomTypeOptions`,
  so `t('ns:key')` is autocompleted and unknown keys are compile errors.
- **Interpolation params** — a `TranslationParams` map (parsed from the value
  placeholders) plus a `createTypedT` wrapper, so `t('key', { … })` params are
  typed. This is beyond what i18next can infer from strings.

## Install

```sh
npm i -D @language-bridge/cli
```

## Usage

```sh
# pull the source locale + generate types in one step (default command)
LB_TOKEN=lb_pat_… lb sync --project my-app --url https://lb.example.com

# equivalent explicit two-step flow
lb pull      --project my-app        # writes raw JSON to --json-dir
lb generate  --out src/@types/resources.d.ts
```

### Options

| Flag | Env | Default | Notes |
|------|-----|---------|-------|
| `--token` | `LB_TOKEN` | — | Bearer token (`lb_pat_…` PAT or a project API token). Required. |
| `--project` | `LB_PROJECT` | — | Project slug. Required. |
| `--url` | `LB_URL` | `http://localhost:3000` | Server base URL. |
| `--locale` | — | project source locale | Locale to generate from. Keys are identical across locales, so the source locale is enough. |
| `--namespace` | — | all | Repeatable; restrict to specific namespaces. |
| `--out` | — | `src/@types/resources.d.ts` | Output `.d.ts` (generate/sync). |
| `--json-dir` | — | `.language-bridge/locales` | Raw JSON location (pull/generate; sync only with `--keep-json`). |
| `--include-drafts` | — | off | Include unpublished values. |
| `--no-params` | — | — | Keys only; skip `TranslationParams`. |
| `--keep-json` | — | off | Have `sync` also write raw JSON. |

Flags override environment, which overrides a config file. Config is discovered by
[cosmiconfig](https://github.com/cosmiconfig/cosmiconfig) — e.g. `language-bridge.json`:

```json
{ "url": "https://lb.example.com", "project": "my-app", "out": "src/@types/resources.d.ts" }
```

## Wiring the generated types into i18next

The generated file augments i18next automatically once it is part of your
TypeScript program (import its types anywhere, e.g. in the setup below). Keys work
through i18next's own `t`:

```ts
import i18next from "i18next";
i18next.t("common:common.welcome"); // autocompleted, checked
```

For **typed interpolation params**, wrap `t` with the shipped helper:

```ts
import i18next from "i18next";
import { createTypedT } from "@language-bridge/cli/runtime";
import type { TranslationParams } from "./@types/resources";

export const tt = createTypedT<TranslationParams>(i18next.t);

tt("common:common.welcome", { name: "Ada" }); // params required + typed
tt("auth:auth.signin");                        // no params -> no second arg
```

Plural keys (`item_one` / `item_other`) collapse to the base key `item` with a
required numeric `count`.

## License

MIT
