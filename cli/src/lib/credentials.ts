// Persisted login tokens, stored per server URL in an OS-appropriate config
// directory (XDG on Linux/mac, %APPDATA% on Windows) with 0600 permissions —
// never in the project tree, so a token can't be committed by accident.
import { chmod, mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

interface Entry {
  token: string;
  user?: string;
}
type Store = Record<string, Entry>;

function configDir(): string {
  if (process.platform === "win32") {
    return join(process.env.APPDATA ?? join(homedir(), "AppData", "Roaming"), "language-bridge");
  }
  const xdg = process.env.XDG_CONFIG_HOME;
  return join(xdg && xdg.length > 0 ? xdg : join(homedir(), ".config"), "language-bridge");
}

// Resolved lazily (and overridable via LB_CREDENTIALS_FILE) so tests never touch
// the real user config.
export function credentialsPath(): string {
  return process.env.LB_CREDENTIALS_FILE ?? join(configDir(), "credentials.json");
}

// Trailing-slash-insensitive key so http://host and http://host/ share an entry.
function key(url: string): string {
  return url.replace(/\/+$/, "");
}

async function loadStore(): Promise<Store> {
  try {
    return JSON.parse(await readFile(credentialsPath(), "utf8")) as Store;
  } catch {
    return {};
  }
}

async function writeStore(store: Store): Promise<void> {
  const file = credentialsPath();
  await mkdir(dirname(file), { recursive: true, mode: 0o700 });
  await writeFile(file, `${JSON.stringify(store, null, 2)}\n`, { mode: 0o600 });
  await chmod(file, 0o600); // enforce perms even if the file pre-existed
}

export async function loadToken(url: string): Promise<string | undefined> {
  return (await loadStore())[key(url)]?.token;
}

export async function saveToken(url: string, entry: Entry): Promise<void> {
  const store = await loadStore();
  store[key(url)] = entry;
  await writeStore(store);
}

// Remove the stored token for a URL. Returns false when there was nothing to do.
export async function removeToken(url: string): Promise<boolean> {
  const store = await loadStore();
  if (!(key(url) in store)) return false;
  delete store[key(url)];
  await writeStore(store);
  return true;
}
