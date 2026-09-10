// Trust-on-first-use for header commands. The config file lives in the repo,
// so a `{ "command": ... }` header value would let any cloned project execute
// an arbitrary command the first time someone runs `lb`. Before a command runs
// it must be approved by a human once (or blanket-allowed via
// LB_TRUST_HEADER_COMMANDS=1 in CI); approvals are remembered in the user's
// config directory, next to the stored credentials.
//
// Approval is scoped to the server URL, not just the command: the command's
// output is sent to that URL, so a malicious repo reusing an already-trusted
// command with its own `url` would otherwise exfiltrate the real token
// without ever prompting.
import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { createInterface } from "node:readline/promises";
import { safely } from "1o1-utils";
import { configDir } from "./credentials.js";

// URL and command are stored alongside their hash so the user can audit what
// they approved with a plain `cat`.
interface Entry {
  url: string;
  command: string;
}
type Store = Record<string, Entry>;

// Overridable via LB_TRUSTED_FILE so tests never touch the real user config.
export function trustedPath(): string {
  return process.env.LB_TRUSTED_FILE ?? join(configDir(), "trusted.json");
}

function digest(url: string, command: string): string {
  return createHash("sha256").update(`${url}\n${command}`).digest("hex");
}

// Missing or unreadable file just means "nothing trusted yet".
async function loadStore(): Promise<Store> {
  const [, store] = await safely(async () => JSON.parse(await readFile(trustedPath(), "utf8")) as Store)();
  return store ?? {};
}

// Whether the command may run for this server: blanket-allowed via env,
// previously approved, or approved interactively right now (and remembered).
export async function ensureTrusted(name: string, command: string, url: string): Promise<boolean> {
  if (process.env.LB_TRUST_HEADER_COMMANDS === "1") return true;

  const store = await loadStore();
  if (digest(url, command) in store) return true;
  if (!process.stdin.isTTY || !process.stderr.isTTY) return false;

  // JSON.stringify escapes control characters, so a config can't smuggle ANSI
  // sequences into the terminal to disguise what is being approved.
  console.error(`The config builds the "${name}" header for ${url} by running:\n\n  ${JSON.stringify(command)}\n`);
  const rl = createInterface({ input: process.stdin, output: process.stderr });
  const answer = (await rl.question("Run it now and trust it for this server? [y/N] ")).trim().toLowerCase();
  rl.close();
  if (answer !== "y" && answer !== "yes") return false;

  store[digest(url, command)] = { url, command };
  const file = trustedPath();
  await mkdir(dirname(file), { recursive: true, mode: 0o700 });
  await writeFile(file, `${JSON.stringify(store, null, 2)}\n`);
  return true;
}
