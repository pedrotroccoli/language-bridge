import { fetchExport, pushProposals } from "../lib/api.js";
import type { ResolvedConfig } from "../lib/config.js";
import { gitBranch } from "../lib/git.js";
import { readJsonDir, selectNamespaces } from "../lib/locales.js";
import type { ImportResponse } from "../lib/types.js";

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
  return pushProposals(config, locale, session, namespaces);
}

// Default push target when --locale is unset: the project's source locale.
async function sourceLocale(config: ResolvedConfig): Promise<string> {
  const { source_locale } = await fetchExport({ ...config, locale: undefined });
  if (!source_locale) throw new Error("Project has no source locale; pass --locale.");
  return source_locale;
}
