# Language Bridge monorepo task runner. `just` = list recipes.

default:
    @just --list

# ── server (Rails app) ───────────────────────────────────────────────────────

# Run the Rails app on :3000 (css watcher + web via Procfile.dev).
server-dev:
    cd server && bin/dev

# Install gems + prepare the dev database.
server-setup:
    cd server && bin/setup

# Run the Rails test suite.
server-test:
    cd server && bin/rails db:test:prepare test

# Lint Ruby.
server-lint:
    cd server && bin/rubocop

# ── cli (@language-bridge/cli) ───────────────────────────────────────────────

# Install CLI deps.
cli-install:
    cd cli && npm install

# Build the CLI to cli/dist.
cli-build:
    cd cli && npm run build

# Run CLI unit tests.
cli-test:
    cd cli && npm test
