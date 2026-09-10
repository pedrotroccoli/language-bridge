import { fetchExport, pushProposals } from "../lib/api.js";
import type { ResolvedConfig } from "../lib/config.js";
import { gitBranch } from "../lib/git.js";
import { readJsonDir, selectNamespaces } from "../lib/locales.js";
import { chunkEntries, flattenNamespaces, nestEntries } from "../lib/tree.js";
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

  let result: ImportResponse | undefined;
  let written = 0;
  for (const chunk of chunkEntries(entries, CHUNK_SIZE)) {
    result = await pushProposals(config, locale, session, nestEntries(chunk));
    written += result.written;
  }
  return { ...result!, written };
}

// Default push target when --locale is unset: the project's source locale.
export async function sourceLocale(config: ResolvedConfig): Promise<string> {
  const { source_locale } = await fetchExport({ ...config, locale: undefined });
  if (!source_locale) throw new Error("Project has no source locale; pass --locale.");
  return source_locale;
}
