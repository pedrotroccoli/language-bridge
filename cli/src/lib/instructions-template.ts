// Single source of truth for the `lb ai-instructions` output. Pure (no imports,
// no I/O) so it can be rendered by the CLI at runtime AND imported by the docs
// site's codegen to keep the published example in sync. Keep it dependency-free.

export interface InstructionsParams {
  project: string;
  // Source locale code, or a human phrase like "the source locale" when unknown.
  source: string;
  // Available locale codes for "This project".
  locales: string[];
  // Sorted namespace names for "This project".
  namespaces: string[];
}

export function buildInstructions({ project, source, locales, namespaces }: InstructionsParams): string {
  return `# Language Bridge — Translation Rules

Managed by \`lb ai-instructions\`. Project: **${project}**.

## Golden rules
- Edit the source locale (\`${source}\`) by default. Only touch another locale
  when the human explicitly asks you to translate into it.
- After editing, run \`lb push\` — it stages your edits as **proposals**.
- A push is a **partial upsert**: the JSON only needs the keys you are adding
  or changing. Keys absent from a push are never deleted or touched.
- NEVER publish. A human reviews each proposal and approves via the UI.
- \`lb pull\` is never required before a push. Pushing an existing key just
  updates its draft — it can't corrupt or delete anything.

## File layout & push targeting
- Files are FLAT: \`<json-dir>/<namespace>.json\` — the file name IS the
  namespace. There are no per-locale folders.
- One push targets exactly ONE locale:
  - \`lb push\` → every namespace file, into the source locale (\`${source}\`)
  - \`lb push --locale <code>\` → the same files' values, into that locale
  - \`lb push --namespace <ns>\` → only \`<ns>.json\` (repeatable)
  - combine both to send one namespace into one locale
- A new namespace is just a new \`<name>.json\` file — push creates it.

## Key format
- Nested JSON inside each namespace file.
- Dotted logical keys inside a namespace: \`home.title\`, \`nav.buttons.save\`.
- Interpolation uses i18next \`{{name}}\` — keep placeholders identical across locales.
- Plurals use \`key_one\` / \`key_other\` suffixes.

## This project
- Source locale: \`${source}\`
- Locales: ${locales.map((code) => `\`${code}\``).join(", ") || "—"}
- Namespaces: ${namespaces.map((name) => `\`${name}\``).join(", ") || "—"}

## Commands
Run \`lb help\` (or \`lb help <command>\`) to discover commands.

Three ways to push, fastest first:
- **One key**: \`lb add <key> "<value>" [-n <namespace>]\` — stages the draft in a
  single command, no files touched. Prefer this when the human asks for one or
  two keys.
- **A few keys**: write \`<json-dir>/<namespace>.json\` containing just those
  keys → \`lb push\`. No pull needed — the push upserts only what the file
  contains.
- **Full round-trip** (editing existing values): \`lb pull\` → edit the source
  JSON in place → \`lb push\`. Large namespaces are pushed in chunks
  automatically.

Either way, a human reviews via \`lb review\`.
CI guard: \`lb check\` exits non-zero while any key exists only in the playground (unpublished).

## Never
- Touch a non-source locale unless explicitly asked.
- Publish or mark anything live.
- Change an existing placeholder's name.
`;
}
