# Changelog

All notable changes to the Language Bridge server are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases ship as `ghcr.io/pedrotroccoli/language-bridge` (tags `v*`).
The CLI has its own changelog in [`cli/CHANGELOG.md`](cli/CHANGELOG.md).

## [0.0.13](https://github.com/pedrotroccoli/language-bridge/compare/v0.0.12...v0.0.13) (2026-09-20)


### Features

* **docs:** add og:url, canonical and image dimensions for link previews ([f67eb7d](https://github.com/pedrotroccoli/language-bridge/commit/f67eb7dff2ac2662a5fc088469561cc36424f9fc))
* **docs:** add og:url, canonical and image dimensions for link previews ([ed5f73f](https://github.com/pedrotroccoli/language-bridge/commit/ed5f73f282686e3cab530f5e4ed5e19a0c32a006))
* **docs:** add site-wide description, open graph and twitter metadata ([9b42378](https://github.com/pedrotroccoli/language-bridge/commit/9b4237861b0cc908b04789da88771b2956345d6b))
* **docs:** add site-wide meta tags and branded og images ([e71d1ed](https://github.com/pedrotroccoli/language-bridge/commit/e71d1ed0ddcce541e30f0d0cb0d59cfac9eba60c))
* **docs:** render og images with the logo and a tighter layout ([9210fd2](https://github.com/pedrotroccoli/language-bridge/commit/9210fd2072d559929d8dc8040f9de9da13611219))
* **docs:** render og images with the logo and a tighter layout ([c180056](https://github.com/pedrotroccoli/language-bridge/commit/c1800562e752e037baa5111a08489409854a28fe))
* **docs:** use figtree and inter in generated og images ([5bf3245](https://github.com/pedrotroccoli/language-bridge/commit/5bf324543ec742cbec3d550222023c68c96da50b))
* **docs:** use figtree and inter in generated og images ([8c349e4](https://github.com/pedrotroccoli/language-bridge/commit/8c349e473b37eb227b0dee439049f6248afa8d31))

## [0.0.12](https://github.com/pedrotroccoli/language-bridge/compare/v0.0.11...v0.0.12) (2026-09-18)


### Bug Fixes

* **playground:** detect s3 via is_a and unwrap mirror service ([a90d1c2](https://github.com/pedrotroccoli/language-bridge/commit/a90d1c25880e55e26e3ab05572e0d8d128cf6ab7))
* **playground:** stamp short cache-control on bucket objects ([1e1ada1](https://github.com/pedrotroccoli/language-bridge/commit/1e1ada102b4a4f78835913fa1d826c30e51c902f))
* **playground:** stamp short cache-control on bucket objects ([77e9cf0](https://github.com/pedrotroccoli/language-bridge/commit/77e9cf0b4e6129a1a7c9017f6b4c06bf15ec2480))

## [0.0.11](https://github.com/pedrotroccoli/language-bridge/compare/v0.0.10...v0.0.11) (2026-09-10)


### Bug Fixes

* **login:** approve and reject opt out of turbo ([f3fddcc](https://github.com/pedrotroccoli/language-bridge/commit/f3fddcc76bac39a0cb33d5df5079c1bdca124ec2))
* **login:** approve and reject opt out of turbo ([f3f2497](https://github.com/pedrotroccoli/language-bridge/commit/f3f24976a20645faa7cd8e0d6fb039efee2878f5))

## [0.0.10](https://github.com/pedrotroccoli/language-bridge/compare/v0.0.9...v0.0.10) (2026-09-10)


### Features

* faster agent-to-draft path — lb add, chunked pushes, honest no-ops ([a75c840](https://github.com/pedrotroccoli/language-bridge/commit/a75c840fb60483e9156dc1a25d99e2d0cb1fed58))


### Bug Fixes

* **api:** identical pushed values are true no-ops ([0d3fba3](https://github.com/pedrotroccoli/language-bridge/commit/0d3fba30afcbd987305ebe68541e45a0a6f4b343))
* **editor:** namespace switcher keeps session, status, search and locale filters ([5f9348d](https://github.com/pedrotroccoli/language-bridge/commit/5f9348d2b21e2aa55355e740f21d5d92334751da))
* **settings:** schema-versioned cache key for the Setting singleton ([ff8ccc8](https://github.com/pedrotroccoli/language-bridge/commit/ff8ccc89148625a81dc1cc9a6db08f49689dfe40))
* **settings:** schema-versioned cache key for the Setting singleton ([5290895](https://github.com/pedrotroccoli/language-bridge/commit/529089563639ba2edb21b8a7bfaf811d1fb771ad))

## [0.0.9](https://github.com/pedrotroccoli/language-bridge/compare/v0.0.8...v0.0.9) (2026-09-08)


### Bug Fixes

* **login:** close the review findings on the CLI authorization flow ([a0d1366](https://github.com/pedrotroccoli/language-bridge/commit/a0d1366799503e210963908b8b16f795fdb1ac7a))
* **login:** fail closed without state and never grant admin ([8a37c56](https://github.com/pedrotroccoli/language-bridge/commit/8a37c56fbed1a49d4276f06bdd10bce748d46479))
* **login:** rejecting reports back to the CLI immediately ([53a13bd](https://github.com/pedrotroccoli/language-bridge/commit/53a13bd260cdf35794c46cdc7ff07bfb4c08f0d9))

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
