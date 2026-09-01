import { fetchExport } from "../lib/api.js";
import type { ResolvedConfig } from "../lib/config.js";
import { selectNamespaces, writeJsonDir } from "../lib/locales.js";
import type { ExportResponse, Namespaces } from "../lib/types.js";

export interface PullResult {
  response: ExportResponse;
  namespaces: Namespaces;
}

// Fetch the export, narrow to the requested namespaces, and (for the standalone
// `pull` command) drop the raw JSON on disk for inspection or a later `generate`.
export async function pull(config: ResolvedConfig, writeDisk: boolean): Promise<PullResult> {
  const response = await fetchExport(config);
  const namespaces = selectNamespaces(response.namespaces, config.namespaces);

  if (writeDisk) {
    await writeJsonDir(config.jsonDir, namespaces);
  }

  return { response, namespaces };
}
