# Language Bridge

Open-source translation management system. A self-hosted, drop-in replacement for Locize at a fraction of the cost.

## Why

Locize charges $200-300/month for something that should be simple: store translation keys, let translators fill in values, serve JSON to your frontend. Language Bridge does exactly that — self-hosted, open-source, and designed for speed.

## What it does

1. **Receives missing keys** — i18next's `saveMissing` sends new keys automatically as your app runs
2. **Translator interface** — Non-technical translators fill in values through a web UI
3. **Serves translations** — Public JSON endpoint with CDN caching, no frontend redeploy needed

For technical details, data model, and API reference, see [Architecture](docs/architecture.md).

## License

MIT
