// Trust-on-first-use for header commands. The config file lives in the repo,
// so a `{ "command": ... }` header value would let any cloned project execute
// an arbitrary command the first time someone runs `lb`. Before a command runs
// it must be approved by a human once (or blanket-allowed via
// LB_TRUST_HEADER_COMMANDS=1 in CI); approvals are remembered by hash in the
// user's config directory, next to the stored credentials.
import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { createInterface } from "node:readline/promises";
import { safely } from "1o1-utils";
import { configDir } from "./credentials.js";

// The command text is stored alongside its hash so the user can audit what
// they approved with a plain `cat`.
type Store = Record<string, string>;

// Overridable via LB_TRUSTED_FILE so tests never touch the real user config.
export function trustedPath(): string {
  return process.env.LB_TRUSTED_FILE ?? join(configDir(), "trusted.json");
}

function digest(command: string): string {
  return createHash("sha256").update(command).digest("hex");
}

// Missing or unreadable file just means "nothing trusted yet".
async function loadStore(): Promise<Store> {
  const [, store] = await safely(async () => JSON.parse(await readFile(trustedPath(), "utf8")) as Store)();
  return store ?? {};
}

// Whether the command may run: blanket-allowed via env, previously approved,
// or approved interactively right now (and remembered for next time).
export async function ensureTrusted(name: string, command: string): Promise<boolean> {
  if (process.env.LB_TRUST_HEADER_COMMANDS === "1") return true;

  const store = await loadStore();
  if (digest(command) in store) return true;
  if (!process.stdin.isTTY || !process.stderr.isTTY) return false;

  console.error(`The config builds the "${name}" header by running:\n\n  ${command}\n`);
  const rl = createInterface({ input: process.stdin, output: process.stderr });
  const answer = (await rl.question("Run it now and trust it from now on? [y/N] ")).trim().toLowerCase();
  rl.close();
  if (answer !== "y" && answer !== "yes") return false;

  store[digest(command)] = command;
  const file = trustedPath();
  await mkdir(dirname(file), { recursive: true, mode: 0o700 });
  await writeFile(file, `${JSON.stringify(store, null, 2)}\n`);
  return true;
}
