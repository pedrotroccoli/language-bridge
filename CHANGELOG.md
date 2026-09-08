# Changelog

All notable changes to the Language Bridge server are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases ship as `ghcr.io/pedrotroccoli/language-bridge` (tags `v*`).
The CLI has its own changelog in [`cli/CHANGELOG.md`](cli/CHANGELOG.md).

## [Unreleased]

### Added

- CLI authorization screen redesigned to the Mono design: requesting-device
  panel, granted and never-able-to capability lists, and a dedicated
  rejection page.
- Verification code on the approval page, derived from the login request so it
  matches the code `lb login` prints — approvals can be tied to the terminal
  that asked for them.

### Changed

- CLI authorization codes now expire after 10 minutes (was 5).

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

[Unreleased]: https://github.com/pedrotroccoli/language-bridge/compare/v0.0.7...HEAD
[0.0.7]: https://github.com/pedrotroccoli/language-bridge/releases/tag/v0.0.7
