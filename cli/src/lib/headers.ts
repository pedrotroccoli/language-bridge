// Custom HTTP headers for servers behind an auth proxy (Cloudflare Access and
// friends): every request the CLI makes can carry extra `Name: Value` pairs
// from --header flags, the LB_HEADERS env var, or the config file's `headers`
// object. Merged per-key, case-insensitively: flag > env > config.

export class HeaderError extends Error {}

// One curl-style "Name: Value" pair, split on the first colon only (values —
// JWTs, URLs — routinely contain colons of their own).
export function parseHeader(pair: string): [string, string] {
  const colon = pair.indexOf(":");
  const name = colon === -1 ? "" : pair.slice(0, colon).trim();
  if (colon === -1 || name === "") {
    throw new HeaderError(`Invalid header "${pair}" — expected "Name: Value".`);
  }
  return [name, pair.slice(colon + 1).trim()];
}

// LB_HEADERS holds several pairs, newline- or comma-separated.
export function parseHeaderList(raw: string): Record<string, string> {
  const headers: Record<string, string> = {};
  for (const part of raw.split(/\r?\n|,/)) {
    if (part.trim() === "") continue;
    const [name, value] = parseHeader(part);
    headers[name] = value;
  }
  return headers;
}

export interface HeaderSources {
  flags?: string[];
  env?: string;
  file?: Record<string, string>;
}

// The merged custom headers, lowest precedence first so later layers win on a
// case-insensitive key match (the winner's casing is kept).
export function resolveHeaders({ flags, env, file }: HeaderSources): Record<string, string> {
  const layers: Record<string, string>[] = [
    file ?? {},
    env ? parseHeaderList(env) : {},
    Object.fromEntries((flags ?? []).map(parseHeader)),
  ];

  const merged: Record<string, string> = {};
  for (const layer of layers) {
    for (const [name, value] of Object.entries(layer)) {
      const existing = Object.keys(merged).find((key) => key.toLowerCase() === name.toLowerCase());
      if (existing !== undefined) delete merged[existing];
      merged[name] = String(value);
    }
  }
  return merged;
}

// Header values regularly hold secrets (service tokens, JWTs) — verbose output
// shows only the names.
export function redactHeaders(headers: Record<string, string>): string {
  return Object.keys(headers)
    .map((name) => `${name}: <redacted>`)
    .join(", ");
}
