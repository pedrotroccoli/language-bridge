// Filesystem + selection helpers shared by the pull/generate/sync commands.
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { pick } from "1o1-utils";
import type { Namespaces, TranslationTree } from "./types.js";

// Keep only the requested namespaces (all of them when `only` is empty).
export function selectNamespaces(all: Namespaces, only?: string[]): Namespaces {
  if (!only || only.length === 0) return all;
  return pick({ obj: all, keys: only }) as Namespaces;
}

// Write each namespace tree as <dir>/<ns>.json (i18next per-namespace layout).
export async function writeJsonDir(dir: string, namespaces: Namespaces): Promise<void> {
  await mkdir(dir, { recursive: true });
  for (const ns of Object.keys(namespaces)) {
    const file = join(dir, `${ns}.json`);
    await writeFile(file, JSON.stringify(namespaces[ns], null, 2) + "\n");
  }
}

// Read a directory of <ns>.json files back into a namespaces map.
export async function readJsonDir(dir: string): Promise<Namespaces> {
  const entries = await readdir(dir);
  const files = entries.filter((name) => name.endsWith(".json"));
  if (files.length === 0) throw new Error(`No .json namespace files in ${dir}`);

  const namespaces: Namespaces = {};
  for (const file of files) {
    const ns = file.slice(0, -".json".length);
    const raw = await readFile(join(dir, file), "utf8");
    namespaces[ns] = JSON.parse(raw) as TranslationTree;
  }
  return namespaces;
}

// Ensure the parent directory of a target file exists, then write it.
export async function writeFileEnsured(path: string, contents: string): Promise<void> {
  const dir = path.includes("/") ? path.slice(0, path.lastIndexOf("/")) : ".";
  await mkdir(dir, { recursive: true });
  await writeFile(path, contents);
}
