# Changelog

All notable changes to `@language-bridge/cli` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this package adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases ship to npm from tags `cli-v*`; every push to `development` publishes
a prerelease under the `canary` dist-tag.

## [Unreleased]

### Added

- `lb login` prints a verification code that must match the one shown on the
  browser approval page, so an authorization request can be tied to the
  terminal that started it.

## [0.1.0] - 2026-09-02

First stable release.

### Added

- `lb init` — interactive project setup (`languagebridge.json`).
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

[Unreleased]: https://github.com/pedrotroccoli/language-bridge/compare/cli-v0.1.0...HEAD
[0.1.0]: https://github.com/pedrotroccoli/language-bridge/releases/tag/cli-v0.1.0
