// Flatten/nest between dotted keys and the nested tree shape the API speaks.
import type { Namespaces, TranslationTree } from "./types.js";

// [namespace, dotted key, value] — one translation entry.
export type Entry = [string, string, string];

export function flattenNamespaces(namespaces: Namespaces): Entry[] {
  const entries: Entry[] = [];
  for (const [namespace, tree] of Object.entries(namespaces)) {
    collect(tree, [], (key, value) => entries.push([namespace, key, value]));
  }
  return entries;
}

function collect(tree: TranslationTree, path: string[], emit: (key: string, value: string) => void): void {
  for (const [part, node] of Object.entries(tree)) {
    if (typeof node === "object" && node !== null) {
      collect(node, [...path, part], emit);
    } else if (node !== null && node !== undefined) {
      // JSON files aren't guaranteed string leaves (numbers, booleans) —
      // coerce like the server would, and skip null like it skips blanks.
      emit([...path, part].join("."), String(node));
    }
  }
}

export function nestEntries(entries: Entry[]): Namespaces {
  const namespaces: Namespaces = {};
  for (const [namespace, key, value] of entries) {
    const tree = (namespaces[namespace] ??= {});
    setPath(tree, key.split("."), value);
  }
  return namespaces;
}

function setPath(tree: TranslationTree, parts: string[], value: string): void {
  const [head, ...rest] = parts as [string, ...string[]];
  if (rest.length === 0) {
    tree[head] = value;
    return;
  }
  const node = tree[head];
  const child = typeof node === "object" && node !== null ? node : (tree[head] = {});
  setPath(child as TranslationTree, rest, value);
}

// Split entries into request-sized slices (the server caps one import at
// MAX_KEYS entries), preserving order.
export function chunkEntries(entries: Entry[], size: number): Entry[][] {
  const chunks: Entry[][] = [];
  for (let index = 0; index < entries.length; index += size) {
    chunks.push(entries.slice(index, index + size));
  }
  return chunks;
}
