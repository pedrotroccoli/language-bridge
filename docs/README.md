# Language Bridge — Docs

The documentation site for Language Bridge. A static Next.js app, deployed to
GitHub Pages at https://pedrotroccoli.github.io/language-bridge/docs.

## Develop

```sh
bun install
bun run dev      # http://localhost:3000/docs
```

## Build

```sh
bun run build    # static export to ./out
```

Set `GITHUB_PAGES=true` to build with the `/language-bridge` base path used on
GitHub Pages (the deploy workflow does this automatically).

## Structure

- `content/docs/` — the pages (MDX). Folder structure defines the URLs;
  `meta.json` files control ordering, titles, icons, and the sidebar root tabs.
- `lib/` — site config: `layout.shared.tsx` (nav), `shared.ts` (site name +
  GitHub info), `source.ts` (content loader).
- `app/` — routes, layouts, search, OG images, `llms.txt`.
- `scripts/gen-cli-snippets.ts` — codegen that renders CLI-owned example snippets
  from `../cli/src` so the docs never drift from the CLI. Runs before `dev`/`build`.

## Editing content

Every page needs a `title` (and ideally a `description`) in its frontmatter. Add
a page by creating an `.mdx` file under `content/docs/`; list it in the folder's
`meta.json` to order it. Don't edit the `.source/` folder — it's generated.
