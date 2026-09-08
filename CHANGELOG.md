# Changelog

All notable changes to the Language Bridge server are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases ship as `ghcr.io/pedrotroccoli/language-bridge` (tags `v*`).
The CLI has its own changelog in [`cli/CHANGELOG.md`](cli/CHANGELOG.md).

## [0.0.8](https://github.com/pedrotroccoli/language-bridge/compare/v0.0.7...v0.0.8) (2026-09-08)


### Features

* **login:** CLI authorization screen from the Mono design ([43c7544](https://github.com/pedrotroccoli/language-bridge/commit/43c75444fc2c2227d14f9f040bcf0f38a6cc34f0))
* **login:** CLI authorization screen from the Mono design ([5628f69](https://github.com/pedrotroccoli/language-bridge/commit/5628f69dd66ee17bd0017c4a26ab25149ce9cab6))
* **login:** verification code binds the approval page to the terminal ([df4b56b](https://github.com/pedrotroccoli/language-bridge/commit/df4b56b7f807d9c21abd32f4e5cd979823a59e5a))


### Bug Fixes

* **login:** approval page polish and 10-minute code TTL ([546c63c](https://github.com/pedrotroccoli/language-bridge/commit/546c63c547bc0b213dce6211c8f3f834ff5d4b73))

## [0.0.7] - 2026-09-02

First stable release from this repository, superseding the images previously
published to Docker Hub (`belzkai/language-bridge`, up to 0.0.6). Images are
now multi-arch (amd64 + arm64) and published on every release tag.

### Added

- AI/CLI translation authoring workflow: pushes from the CLI land as
  unpublished drafts tagged with a session (git branch or chat), reviewable
  and publishable in the editor — nothing publishes through the API.
- `lb login` loopback flow: a signed-in user approves the CLI on the web and a
  personal access token is minted with explicit capabilities (read,
  read drafts, write — never admin).
- Playground and per-session preview artifacts materialized in the connected
  storage, so frontends can point at drafts before anything publishes.
- Push accepts any of the project's locales (source locale remains the
  default).
- Command line section in project settings with install and usage snippets.

### Fixed

- Editor keeps search and filters after creating or deleting keys.
- Project "last updated" now reflects translation activity, not just settings
  changes.
- Storage keys are hardened against path traversal in session artifacts.
- One-time CLI auth codes can no longer be redeemed twice under a race.

[0.0.7]: https://github.com/pedrotroccoli/language-bridge/releases/tag/v0.0.7
