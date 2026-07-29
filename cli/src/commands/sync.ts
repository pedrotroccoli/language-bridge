import type { ResolvedConfig } from "../lib/config.js";
import { emit } from "../lib/emit.js";
import { writeFileEnsured, writeJsonDir } from "../lib/locales.js";
import { pull } from "./pull.js";

export interface SyncResult {
  out: string;
  locale: string;
  namespaces: string[];
}

// The primary command: pull -> generate types in one shot. Temp JSON is only
// written when --keep-json is set (mirrors locize's `loc:d && loc:i && rm`).
export async function sync(config: ResolvedConfig): Promise<SyncResult> {
  const { response, namespaces } = await pull(config, false);
  const dts = emit(namespaces, { params: config.params, locale: response.locale });
  await writeFileEnsured(config.out, dts);

  if (config.keepJson) {
    await writeJsonDir(config.jsonDir, namespaces);
  }

  return { out: config.out, locale: response.locale, namespaces: Object.keys(namespaces) };
}
