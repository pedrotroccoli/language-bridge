import { readFile } from "node:fs/promises";
import { fetchExport } from "../lib/api.js";
import type { ResolvedConfig } from "../lib/config.js";
import { writeFileEnsured } from "../lib/locales.js";

// Markers delimit the managed block so re-running updates it in place instead of
// appending a duplicate (idempotent, like a generated section).
const START = "<!-- lb:start -->";
const END = "<!-- lb:end -->";

export const DEFAULT_INSTRUCTIONS_FILE = "AGENTS.md";

// Render project-specific rules an AI agent follows before touching translations
// (which locale to edit, how to push, what it must never do). Enriched with the
// project's real namespaces/locales pulled from the export endpoint.
export async function renderInstructions(config: ResolvedConfig): Promise<string> {
  const meta = await fetchExport({ ...config, locale: undefined });
  const namespaces = Object.keys(meta.namespaces).sort();
  const source = meta.source_locale ?? "the source locale";

  return `# Language Bridge — Translation Rules

Managed by \`lb ai-instructions\`. Project: **${config.project}**.

## Golden rules
- Edit the source locale (\`${source}\`) by default. Only touch another locale
  when the human explicitly asks you to translate into it.
- After editing, run \`lb push\` — it stages your edits as **proposals**.
- A push is a **partial upsert**: the JSON only needs the keys you are adding
  or changing. Keys absent from a push are never deleted or touched.
- NEVER publish. A human reviews each proposal and approves via the UI.
- Check existing keys before inventing one (\`lb pull\`, or read the local
  JSON if it's already there) — but pulling is NOT a prerequisite to push.

## Key format
- Nested JSON, one file per namespace (\`<namespace>.json\`).
- Dotted logical keys inside a namespace: \`home.title\`, \`nav.buttons.save\`.
- Interpolation uses i18next \`{{name}}\` — keep placeholders identical across locales.
- Plurals use \`key_one\` / \`key_other\` suffixes.

## This project
- Source locale: \`${source}\`
- Locales: ${meta.available_locales.map((code) => `\`${code}\``).join(", ") || "—"}
- Namespaces: ${namespaces.map((name) => `\`${name}\``).join(", ") || "—"}

## Commands
Run \`lb help\` (or \`lb help <command>\`) to discover commands.

Two ways to push:
- **Quick add** (a few new keys): write \`<json-dir>/<namespace>.json\` containing
  just those keys → \`lb push\`. No pull needed — the push upserts only what the
  file contains.
- **Full round-trip** (editing existing values): \`lb pull\` → edit the source
  JSON in place → \`lb push\`.

Either way, a human reviews via \`lb review\`.
CI guard: \`lb check\` exits non-zero while any key exists only in the playground (unpublished).

## Never
- Touch a non-source locale unless explicitly asked.
- Publish or mark anything live.
- Change an existing placeholder's name.
`;
}

// Wrap the block in markers and splice it into an existing file (replacing any
// prior lb block), or return a fresh marked block when the file is absent.
export async function writeInstructions(path: string, block: string): Promise<void> {
  const wrapped = `${START}\n${block.trimEnd()}\n${END}\n`;
  let existing = "";
  try {
    existing = await readFile(path, "utf8");
  } catch {
    existing = "";
  }

  const start = existing.indexOf(START);
  const end = existing.indexOf(END);
  let next: string;
  if (start !== -1 && end !== -1 && end > start) {
    next = existing.slice(0, start) + wrapped.trimEnd() + existing.slice(end + END.length);
  } else if (existing.trim()) {
    next = `${existing.trimEnd()}\n\n${wrapped}`;
  } else {
    next = wrapped;
  }

  await writeFileEnsured(path, next.endsWith("\n") ? next : `${next}\n`);
}
