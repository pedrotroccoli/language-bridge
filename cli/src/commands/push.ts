import { fetchExport, pushProposals } from "../lib/api.js";
import type { ResolvedConfig } from "../lib/config.js";
import { gitBranch } from "../lib/git.js";
import { readJsonDir, selectNamespaces } from "../lib/locales.js";
import type { ImportResponse } from "../lib/types.js";

// Read the local source-locale JSON and push each value as a reviewable
// proposal. Nothing goes live: a human accepts/rejects on the platform. The
// server flattens the nested tree and skips blank leaves. The session (given, or
// the current git branch) keeps parallel branches/chats from clobbering.
export async function push(config: ResolvedConfig): Promise<ImportResponse> {
  const all = await readJsonDir(config.jsonDir);
  const namespaces = selectNamespaces(all, config.namespaces);
  const locale = config.locale ?? (await sourceLocale(config));
  const session = config.session ?? (await gitBranch()) ?? "";
  return pushProposals(config, locale, session, namespaces);
}

// Proposals only target the source locale; discover it when --locale is unset.
async function sourceLocale(config: ResolvedConfig): Promise<string> {
  const { source_locale } = await fetchExport({ ...config, locale: undefined });
  if (!source_locale) throw new Error("Project has no source locale; pass --locale.");
  return source_locale;
}
