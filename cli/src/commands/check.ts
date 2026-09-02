import { fetchExport } from "../lib/api.js";
import type { ResolvedConfig } from "../lib/config.js";
import type { Namespaces, TranslationTree } from "../lib/types.js";

export interface CheckResult {
  project: string;
  ok: boolean;
  // Fully-qualified keys ("ns:a.b") that exist only as drafts — the playground
  // has them, production delivery does not.
  unpublished: string[];
}

// CI guard for the playground workflow: a dev pointing at the playground can
// ship code using keys nobody published yet, and prod would render the raw key.
// Compares the published export against the drafts-included one; any key in the
// diff is playground-only. Exit code is handled by the caller.
export async function check(config: ResolvedConfig): Promise<CheckResult> {
  const [published, withDrafts] = await Promise.all([
    fetchExport({ ...config, includeDrafts: false }),
    fetchExport({ ...config, includeDrafts: true }),
  ]);

  const live = new Set(allKeys(published.namespaces));
  const unpublished = allKeys(withDrafts.namespaces).filter((key) => !live.has(key));
  return { project: config.project, ok: unpublished.length === 0, unpublished };
}

function allKeys(namespaces: Namespaces): string[] {
  const keys: string[] = [];
  for (const ns of Object.keys(namespaces)) {
    for (const path of leafPaths(namespaces[ns]!)) keys.push(`${ns}:${path}`);
  }
  return keys;
}

function* leafPaths(tree: TranslationTree, prefix = ""): Generator<string> {
  for (const key of Object.keys(tree)) {
    const value = tree[key]!;
    const path = prefix ? `${prefix}.${key}` : key;
    if (typeof value === "string") yield path;
    else yield* leafPaths(value, path);
  }
}
