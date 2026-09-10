# Changelog

All notable changes to `@language-bridge/cli` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this package adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases ship to npm from tags `cli-v*`; every push to `development` publishes
a prerelease under the `canary` dist-tag.

## [0.1.3](https://github.com/pedrotroccoli/language-bridge/compare/cli-v0.1.2...cli-v0.1.3) (2026-09-10)


### Features

* **cli:** custom headers for servers behind an auth proxy ([8bd4e59](https://github.com/pedrotroccoli/language-bridge/commit/8bd4e59ccf78a786b47400de995663ef6c6458ac))
* **cli:** custom headers for servers behind an auth proxy ([b19900a](https://github.com/pedrotroccoli/language-bridge/commit/b19900ab07f50bd7b0d0c731ce5d064224b72260))


### Bug Fixes

* **cli:** harden custom-header handling from review ([e02bf08](https://github.com/pedrotroccoli/language-bridge/commit/e02bf0847a2518064d3a468e1e2bfc3580f8f8f8))

## [0.1.2](https://github.com/pedrotroccoli/language-bridge/compare/cli-v0.1.1...cli-v0.1.2) (2026-09-08)


### Bug Fixes

* **cli:** mark the loopback promise handled before login awaits it ([ab449ed](https://github.com/pedrotroccoli/language-bridge/commit/ab449ede72f705afff07d54f6eb99c5a6be9a738))
* **login:** close the review findings on the CLI authorization flow ([a0d1366](https://github.com/pedrotroccoli/language-bridge/commit/a0d1366799503e210963908b8b16f795fdb1ac7a))
* **login:** rejecting reports back to the CLI immediately ([53a13bd](https://github.com/pedrotroccoli/language-bridge/commit/53a13bd260cdf35794c46cdc7ff07bfb4c08f0d9))

## [0.1.1](https://github.com/pedrotroccoli/language-bridge/compare/cli-v0.1.0...cli-v0.1.1) (2026-09-08)


### Features

* **login:** CLI authorization screen from the Mono design ([43c7544](https://github.com/pedrotroccoli/language-bridge/commit/43c75444fc2c2227d14f9f040bcf0f38a6cc34f0))
* **login:** verification code binds the approval page to the terminal ([df4b56b](https://github.com/pedrotroccoli/language-bridge/commit/df4b56b7f807d9c21abd32f4e5cd979823a59e5a))

## [0.1.0] - 2026-09-02

First stable release.

### Added

- `lb init` — interactive project setup (`language-bridge.json`).
- `lb login` / `lb logout` / `lb whoami` — browser-approved authentication;
  the token is stored globally, never in the project tree.
- `lb pull` — export translations as per-namespace JSON files.
- `lb push` — upload draft translations for review; accepts any of the
  project's locales via `--locale` (source locale by default).
- `lb sync` — pull followed by type generation.
- `lb generate` — TypeScript types for the project's translation keys.
- `lb check` — verify local files against the project.
- `lb review` — open the editor filtered to the current push session.
- `lb ai-instructions` — usage instructions for AI coding agents.
- `lb completion` — shell completions.

[0.1.0]: https://github.com/pedrotroccoli/language-bridge/releases/tag/cli-v0.1.0
