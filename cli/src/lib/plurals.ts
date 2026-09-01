// i18next plural suffixes (_one/_other/…) are variants of one base key selected
// by `count`; we collapse them to the base and require a numeric `count`.
const PLURAL_SUFFIX = /_(zero|one|two|few|many|other)$/;

// The base key for a plural variant, or null when the segment is not a variant.
//   "item_one" -> "item"    "greeting" -> null
export function pluralBase(segment: string): string | null {
  const match = PLURAL_SUFFIX.exec(segment);
  if (!match) return null;
  const base = segment.slice(0, match.index);
  return base.length > 0 ? base : null;
}
