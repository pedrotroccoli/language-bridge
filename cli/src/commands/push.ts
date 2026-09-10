import { chunk } from "1o1-utils";
import { fetchExport, pushProposals } from "../lib/api.js";
import type { ResolvedConfig } from "../lib/config.js";
import { gitBranch } from "../lib/git.js";
import { readJsonDir, selectNamespaces } from "../lib/locales.js";
import { flattenNamespaces, nestEntries } from "../lib/tree.js";
import type { ImportResponse, Namespaces } from "../lib/types.js";

// The server caps one import request at 2000 entries (MAX_KEYS in
// imports_controller.rb); bigger pushes are sliced into sequential requests
// so a large namespace still round-trips instead of 422ing.
const CHUNK_SIZE = 2000;

// Read the local JSON and push each value as a reviewable proposal — for the
// given --locale, or the project's source locale by default. Nothing goes live:
// a human accepts/rejects on the platform. The server flattens the nested tree
// and skips blank leaves. The session (given, or the current git branch) keeps
// parallel branches/chats from clobbering.
export async function push(config: ResolvedConfig): Promise<ImportResponse> {
  const all = await readJsonDir(config.jsonDir);
  const namespaces = selectNamespaces(all, config.namespaces);
  const locale = config.locale ?? (await sourceLocale(config));
  const session = config.session ?? (await gitBranch()) ?? "";
  return pushChunked(config, locale, session, namespaces);
}

async function pushChunked(config: ResolvedConfig, locale: string, session: string, namespaces: Namespaces): Promise<ImportResponse> {
  const entries = flattenNamespaces(namespaces);
  if (entries.length <= CHUNK_SIZE) return pushProposals(config, locale, session, namespaces);

  const chunks = chunk({ array: entries, size: CHUNK_SIZE });
  const previewPaths = new Set<string>();
  const playgroundPaths = new Set<string>();
  let result: ImportResponse | undefined;
  let written = 0;
  for (const [index, slice] of chunks.entries()) {
    try {
      result = await pushProposals(config, locale, session, nestEntries(slice));
    } catch (cause) {
      // Earlier chunks are already staged as drafts; pushes are idempotent,
      // so retrying the whole thing is safe — say so instead of implying
      // nothing landed.
      throw new Error(
        `Push failed on part ${index + 1}/${chunks.length} — ${written} draft(s) from earlier parts are already staged; re-running the same push is safe. ${(cause as Error).message}`,
      );
    }
    written += result.written;
    for (const path of result.preview_paths ?? []) previewPaths.add(path);
    for (const path of result.playground_paths ?? []) playgroundPaths.add(path);
  }
  return { ...result!, written, preview_paths: [...previewPaths], playground_paths: [...playgroundPaths] };
}

// Default push target when --locale is unset: the project's source locale.
async function sourceLocale(config: ResolvedConfig): Promise<string> {
  const { source_locale } = await fetchExport({ ...config, locale: undefined });
  if (!source_locale) throw new Error("Project has no source locale; pass --locale.");
  return source_locale;
}
