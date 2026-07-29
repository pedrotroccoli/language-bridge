import type { ResolvedConfig } from "../lib/config.js";
import { emit } from "../lib/emit.js";
import { readJsonDir, selectNamespaces, writeFileEnsured } from "../lib/locales.js";

// Read previously-pulled JSON from jsonDir and emit the .d.ts. Standalone
// counterpart to `pull`; useful for regenerating types offline.
export async function generate(config: ResolvedConfig): Promise<void> {
  const all = await readJsonDir(config.jsonDir);
  const namespaces = selectNamespaces(all, config.namespaces);
  const dts = emit(namespaces, { params: config.params, locale: config.locale });
  await writeFileEnsured(config.out, dts);
}
