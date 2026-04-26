---
tags: [rails, 37signals, style-guide, compass]
---

# 37signals Rails Compass

> Transferable Rails patterns and development philosophy extracted from 265 PRs in 37signals' Fizzy codebase.
> Source: [unofficial-37signals-coding-style-guide](https://github.com/marckohlbrugge/unofficial-37signals-coding-style-guide)

## Quick Start — The 37signals Way

1. **Rich domain models** over service objects
2. **CRUD controllers** over custom actions
3. **Concerns** for horizontal code sharing
4. **Records as state** over boolean columns
5. **Database-backed everything** (no Redis)
6. **Build it yourself** before reaching for gems
7. **Ship to learn** - prototype quality is valid
8. **Vanilla Rails is plenty** - maximize what Rails gives you

---

## Philosophy & Principles

- [[philosophy]] — Ship, Validate, Refine & core development principles
- [[dhh-patterns]] — DHH's code review patterns from 100+ PR reviews
- [[jorge-manrubia]] — Architecture, Rails patterns & performance
- [[jason-zimdars]] — Design, product & UX patterns
- [[what-they-avoid]] — Gems and abstractions 37signals deliberately skips

## Core Rails

- [[routing]] — Everything is CRUD, noun-based resources
- [[controllers]] — Thin controllers, rich models, concern catalog
- [[models]] — Concerns, state records, POROs, scopes
- [[views]] — Turbo Streams, partials, caching, helpers

## Frontend

- [[stimulus]] — Reusable controllers catalog & best practices
- [[css]] — Native CSS, cascade layers, OKLCH, dark mode
- [[hotwire]] — Turbo morphing, frames, state persistence, drag & drop
- [[accessibility]] — ARIA, keyboard nav, screen readers, focus
- [[mobile]] — Responsive design, touch optimization, safe areas

## Backend

- [[authentication]] — Passwordless magic links, sessions, rate limiting
- [[multi-tenancy]] — Path-based tenancy, middleware, job preservation
- [[database]] — UUIDs, state records, Solid Stack, indexing
- [[background-jobs]] — Solid Queue, error handling, continuable jobs
- [[caching]] — HTTP ETags, fragment caching, touch chains
- [[performance]] — N+1, Puma tuning, lazy loading, preloaded scopes

## Real-Time & Communication

- [[actioncable]] — Multi-tenant WebSockets, scoped broadcasts, Solid Cable
- [[notifications]] — Bundling, real-time via Turbo, email unsubscribe
- [[email]] — Multi-tenant URLs, timezone awareness, SMTP resilience

## Features

- [[webhooks]] — SSRF protection, HMAC signatures, delinquency tracking
- [[workflows]] — Event-driven state, undoable commands, custom Turbo actions
- [[watching]] — Involvement enum, collection vs resource watching
- [[filtering]] — Persisted filter objects, composable scopes
- [[ai-llm]] — Command pattern, cost tracking, tool pattern

## Rails Components

- [[active-storage]] — Preprocessing, upload expiry, avatar optimization
- [[action-text]] — Sanitizer config, autolinking, link retargeting

## Infrastructure & Testing

- [[security]] — XSS, CSRF, SSRF, CSP, rate limiting
- [[testing]] — Minitest, fixtures, VCR, integration tests
- [[configuration]] — Master key, YAML anchors, Kamal
- [[observability]] — Structured logging, Yabeda metrics, console auditing
