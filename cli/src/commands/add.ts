import { fetchExport, pushProposals } from "../lib/api.js";
import type { ResolvedConfig } from "../lib/config.js";
import { gitBranch } from "../lib/git.js";
import { nestEntries } from "../lib/tree.js";
import type { ImportResponse } from "../lib/types.js";

// One-shot key push: `lb add home.title "Welcome"` stages a single draft
// without touching any local file — the fastest path from "add this key" to a
// reviewable proposal. Namespace comes from --namespace, or is inferred when
// the project has exactly one.
export async function add(config: ResolvedConfig, key: string, value: string): Promise<ImportResponse & { namespace: string }> {
  const meta = await fetchExport({ ...config, locale: undefined });
  const namespace = config.namespaces?.[0] ?? onlyNamespace(Object.keys(meta.namespaces));
  const locale = config.locale ?? meta.source_locale;
  if (!locale) throw new Error("Project has no source locale; pass --locale.");

  const session = config.session ?? (await gitBranch()) ?? "";
  const result = await pushProposals(config, locale, session, nestEntries([[namespace, key, value]]));
  return { ...result, namespace };
}

function onlyNamespace(names: string[]): string {
  if (names.length === 1) return names[0]!;
  if (names.length === 0) throw new Error("Project has no namespaces yet — pass --namespace to create one.");
  throw new Error(`Project has ${names.length} namespaces (${names.sort().join(", ")}) — pass --namespace.`);
}
