// i18next pluralisation is a key-suffix convention: `item_one` / `item_other`
// (also _zero/_two/_few/_many) are variants of one logical key `item`, selected
// at runtime by a `count`. For param typing we collapse the variants to their
// base key and require a numeric `count`.
const PLURAL_SUFFIX = /_(zero|one|two|few|many|other)$/;

// The base key for a plural variant, or null when the segment is not a variant.
//   "item_one" -> "item"    "greeting" -> null
export function pluralBase(segment: string): string | null {
  const match = PLURAL_SUFFIX.exec(segment);
  if (!match) return null;
  const base = segment.slice(0, match.index);
  return base.length > 0 ? base : null;
}
