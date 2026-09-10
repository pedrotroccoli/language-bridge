// Custom HTTP headers for servers behind an auth proxy (Cloudflare Access and
// friends): every request the CLI makes can carry extra `Name: Value` pairs
// from --header flags, the LB_HEADERS env var, or the config file's `headers`
// object. Merged per-key, case-insensitively: flag > env > config.
//
// A config value can also be `{ "command": "..." }`: the command runs once per
// process and its stdout becomes the header — for tokens that expire and live
// in a helper (`cloudflared access token`), so nobody has to export a fresh
// JWT before every command.
import { exec } from "node:child_process";
import { memo } from "1o1-utils";
import { ensureTrusted } from "./trust.js";

export class HeaderError extends Error {}

export type FileHeaderValue = string | { command: string };

// One curl-style "Name: Value" pair, split on the first colon only (values —
// JWTs, URLs — routinely contain colons of their own). The name is validated
// here so a typo fails with this message instead of fetch's distant
// "invalid header name" TypeError.
export function parseHeader(pair: string): [string, string] {
  const colon = pair.indexOf(":");
  const name = colon === -1 ? "" : pair.slice(0, colon).trim();
  if (colon === -1 || !/^[\w-]+$/.test(name)) {
    throw new HeaderError(`Invalid header "${pair}" — expected "Name: Value".`);
  }
  return [name, pair.slice(colon + 1).trim()];
}

// LB_HEADERS holds several pairs, newline- or comma-separated. Commas only
// act as separators when there are no newlines, so values containing commas
// (cookies) stay intact under newline separation.
export function parseHeaderList(raw: string): Record<string, string> {
  const headers: Record<string, string> = {};
  const parts = /\r?\n/.test(raw) ? raw.split(/\r?\n/) : raw.split(",");
  for (const part of parts) {
    if (part.trim() === "") continue;
    const [name, value] = parseHeader(part);
    headers[name] = value;
  }
  return headers;
}

export interface HeaderSources {
  flags?: string[];
  env?: string;
  file?: Record<string, FileHeaderValue>;
  // The server the headers will be sent to; command approval is scoped to it.
  url: string;
}

// The merged custom headers, lowest precedence first so later layers win on a
// case-insensitive key match (the winner's casing is kept). Merge first,
// execute after: a command that a flag/env layer overrides — or one behind a
// reserved name the CLI would discard anyway — must neither spawn nor prompt.
export async function resolveHeaders({ flags, env, file, url }: HeaderSources): Promise<Record<string, string>> {
  const layers: Record<string, FileHeaderValue>[] = [
    file ?? {},
    env ? parseHeaderList(env) : {},
    Object.fromEntries((flags ?? []).map(parseHeader)),
  ];

  const merged: Record<string, FileHeaderValue> = {};
  for (const layer of layers) {
    for (const [name, value] of Object.entries(layer)) {
      const existing = Object.keys(merged).find((key) => key.toLowerCase() === name.toLowerCase());
      if (existing !== undefined) delete merged[existing];
      merged[name] = value;
    }
  }

  const headers: Record<string, string> = {};
  for (const [name, value] of Object.entries(merged)) {
    // Flag/env names go through parseHeader; config names arrive raw, and one
    // with control characters could smuggle ANSI sequences into the trust
    // prompt — so everything is (re)validated here, shown escaped.
    if (!/^[\w-]+$/.test(name)) {
      throw new HeaderError(`Invalid header name ${JSON.stringify(name)} in config — letters, digits, "-" and "_" only.`);
    }
    if (typeof value === "object" && value !== null) {
      if (typeof value.command !== "string" || value.command.trim() === "") {
        throw new HeaderError(`Invalid header "${name}" in config — expected a string or { "command": "..." }.`);
      }
      if (RESERVED.includes(name.toLowerCase())) continue;
      headers[name] = await commandValue(name, value.command, url);
    } else {
      headers[name] = String(value);
    }
  }
  return headers;
}

// A hung helper must not hang lb forever (a command waiting on interactive
// input, say) — stdin is closed and the child killed after this long.
const COMMAND_TIMEOUT_MS = 60_000;

// One spawn per command per server per process: several resolves in one run
// (push chunks, multi-project, login + whoami) reuse the value. Cross-process
// caching is the helper's job — cloudflared already persists its token until
// expiry.
const commandValue = memo({
  key: ([, command, url]: [string, string, string]) => `${url}\n${command}`,
  fn: (name: string, command: string, url: string) => runCommand(name, command, url),
});

async function runCommand(name: string, command: string, url: string): Promise<string> {
  if (!(await ensureTrusted(name, command, url))) {
    throw new HeaderError(
      `Header "${name}": refusing to run \`${command}\` — not trusted for ${url}. ` +
        "Approve it by running any lb command interactively, or set LB_TRUST_HEADER_COMMANDS=1 (CI).",
    );
  }

  let stdout: string;
  try {
    stdout = await new Promise<string>((resolve, reject) => {
      // Plain exec callbacks don't attach stderr to the error (promisify's
      // wrapper does) — carried over so the failure message can show it.
      const child = exec(command, { timeout: COMMAND_TIMEOUT_MS }, (error, out, errOut) => {
        if (error) reject(Object.assign(error, { stderr: errOut }));
        else resolve(out);
      });
      child.stdin?.end();
    });
  } catch (cause) {
    const failure = cause as Error & { stderr?: string; killed?: boolean };
    const detail = failure.killed
      ? `timed out after ${COMMAND_TIMEOUT_MS / 1000}s (is it waiting for input?)`
      : failure.stderr?.trim() || failure.message;
    throw new HeaderError(`Header "${name}": command failed — ${detail}`);
  }

  const value = stdout.trim();
  if (value === "") throw new HeaderError(`Header "${name}": command produced no output.`);
  if (/[\r\n]/.test(value)) throw new HeaderError(`Header "${name}": command produced multiple lines — a header value must be a single line.`);
  return value;
}

// Headers the CLI owns. Filtered from the custom set case-insensitively —
// otherwise a lowercase `authorization` would survive the object spread as a
// distinct key, and the fetch spec fills Headers from a record with `append`,
// combining both values into one broken header.
const RESERVED = ["authorization", "accept", "content-type"];

export function withoutReserved(headers: Record<string, string>): Record<string, string> {
  return Object.fromEntries(Object.entries(headers).filter(([name]) => !RESERVED.includes(name.toLowerCase())));
}

// Header values regularly hold secrets (service tokens, JWTs) — verbose output
// shows only the names.
export function redactHeaders(headers: Record<string, string>): string {
  return Object.keys(headers)
    .map((name) => `${name}: <redacted>`)
    .join(", ");
}
