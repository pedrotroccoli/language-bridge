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
# authorize this machine in your browser once (stores a token — see Authentication)
lb login --url https://lb.example.com

# pull the source locale + generate types in one step (default command)
lb sync --project my-app

# equivalent explicit two-step flow
lb pull      --project my-app        # writes raw JSON to --json-dir
lb generate  --out src/@types/resources.d.ts

# push local source-locale edits as reviewable proposals (nothing goes live)
lb push      --project my-app        # POST /import — a human accepts/rejects in the UI

# emit AI-agent rules for this project (stdout, or into AGENTS.md)
lb ai-instructions --project my-app --write
```

### Authoring flow (AI-driven)

`lb push` is the write counterpart of `lb pull`. It uploads the local source-locale
JSON as **proposals**: staged values a human reviews on the platform (Proposals tab)
before anything is applied or published. An automated push can never clobber a live
string. Proposals target the source locale only — the platform translates the rest.

Each push carries a **session** (defaults to the current git branch, override with
`--session` / `LB_SESSION`). Proposals are grouped by session on the platform, so two
branches or AI chats can propose the *same* key without overwriting each other —
re-pushing the same session updates its own proposals in place.

`lb ai-instructions` prints project-specific rules (which locale to edit, how to push,
what never to do) an AI agent can follow; `--write` splices them into `AGENTS.md`
between `<!-- lb:start -->`/`<!-- lb:end -->` markers (idempotent).

### Authentication

```sh
lb login    # opens the browser, authorizes this machine, stores a token
lb whoami   # show the user + projects the stored token can reach
lb logout   # forget the stored token for this server
```

`lb login` runs a loopback flow: it starts a temporary server on `127.0.0.1`, opens
the platform's authorize page, and — after you approve — receives a one-time code
that it exchanges for a personal access token. The token is stored per server URL in

- `$XDG_CONFIG_HOME/language-bridge/credentials.json` (Linux/macOS, default `~/.config`)
- `%APPDATA%\language-bridge\credentials.json` (Windows)

with `0600` permissions — never in the project tree, so it can't be committed. Each
login mints a **named** token (defaults to your hostname; `--name` to override), so
every machine has its own revocable token. A workspace admin caps how many tokens a
user may hold (default 3) in Workspace settings.

For CI, skip `lb login` and pass `LB_TOKEN` (a `lb_pat_…` PAT or project API token).

### Options

| Flag | Env | Default | Notes |
|------|-----|---------|-------|
| `--token` | `LB_TOKEN` | stored login | Bearer token (`lb_pat_…` PAT or a project API token). Falls back to the token saved by `lb login`. |
| `--project` | `LB_PROJECT` | — | Project slug. Required (except `login`/`logout`/`whoami`). |
| `--url` | `LB_URL` | `http://localhost:3000` | Server base URL. |
| `--locale` | — | project source locale | Locale to generate from. Keys are identical across locales, so the source locale is enough. |
| `--namespace` | — | all | Repeatable; restrict to specific namespaces. |
| `--out` | — | `src/@types/resources.d.ts` | Output `.d.ts` (generate/sync). |
| `--json-dir` | — | `.language-bridge/locales` | Raw JSON location (pull/generate; sync only with `--keep-json`). |
| `--include-drafts` | — | off | Include unpublished values. |
| `--no-params` | — | — | Keys only; skip `TranslationParams`. |
| `--keep-json` | — | off | Have `sync` also write raw JSON. |

Flags override environment, which overrides a config file. Config is discovered by
[cosmiconfig](https://github.com/cosmiconfig/cosmiconfig) — `language-bridge.json`,
`.language-bridgerc[.json|.yaml]`, `language-bridge.config.js`, or a `languageBridge`
key in `package.json`:

```json
{ "url": "https://lb.example.com", "project": "my-app", "out": "src/@types/resources.d.ts" }
```

### Multiple projects

A monorepo can consume several projects from one config via a `projects` list. Each
entry names a `project` slug and may override `locale`, `namespaces`, `out`, `jsonDir`,
`params`, `session`; anything omitted inherits the top-level defaults, then a per-slug
default (`src/@types/<slug>.d.ts`, `.language-bridge/<slug>`) so outputs never collide.

```json
{
  "url": "https://lb.example.com",
  "projects": [
    { "project": "main-app", "out": "src/@types/main.d.ts" },
    { "project": "marketing", "namespaces": ["landing"] }
  ]
}
```

Commands (`pull`, `generate`, `sync`, `push`) run for **every** listed project;
`--project <slug>` narrows to one. With several projects resolved, the single-project
flags (`--out`, `--json-dir`, `--locale`, `--namespace`) are rejected as ambiguous —
set them per entry instead.

### Validating

```sh
lb validate   # (alias: lb valid)
```

Checks the config end-to-end: the token works, every configured project exists and is
reachable, and each configured `locale`/`namespaces` actually exists on the server.
Prints `✓`/`✗` per project and exits non-zero on any failure — handy in CI before a push.

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
