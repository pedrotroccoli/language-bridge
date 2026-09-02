// Once-a-day update check against the npm registry, printed to stderr after the
// command finishes. Silent on any failure (offline, unpublished package) and
// skipped entirely in CI / non-TTY / LB_NO_UPDATE_CHECK=1.
import { readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { safely, withTimeout } from "1o1-utils";
import { credentialsPath } from "./credentials.js";

const CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000;
const FETCH_TIMEOUT_MS = 2_000;

interface Cache {
  checkedAt: number;
  latest: string;
}

function cacheFile(): string {
  return join(dirname(credentialsPath()), "update-check.json");
}

// "1.2.10" newer than "1.2.9"? Plain numeric segment compare (no prerelease).
export function isNewer(latest: string, current: string): boolean {
  const a = latest.split(".").map(Number);
  const b = current.split(".").map(Number);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const diff = (a[i] ?? 0) - (b[i] ?? 0);
    if (diff !== 0) return diff > 0;
  }
  return false;
}

async function latestVersion(name: string): Promise<string | undefined> {
  const [, cached] = await safely(async () => JSON.parse(await readFile(cacheFile(), "utf8")) as Cache)();
  if (cached && Date.now() - cached.checkedAt < CHECK_INTERVAL_MS) return cached.latest;

  const [, latest] = await safely(async () => {
    const response = await withTimeout({
      promise: fetch(`https://registry.npmjs.org/${encodeURIComponent(name)}/latest`, { headers: { Accept: "application/json" } }),
      ms: FETCH_TIMEOUT_MS,
    });
    if (!response.ok) throw new Error(`registry ${response.status}`);
    return ((await response.json()) as { version: string }).version;
  })();

  if (latest) await safely(writeFile)(cacheFile(), JSON.stringify({ checkedAt: Date.now(), latest } satisfies Cache));
  return latest;
}

export async function maybeNotifyUpdate(name: string, current: string): Promise<void> {
  if (process.env.CI || process.env.LB_NO_UPDATE_CHECK === "1" || !process.stderr.isTTY) return;
  const latest = await latestVersion(name);
  if (latest && isNewer(latest, current)) {
    console.error(`\nlb: update available ${current} → ${latest}. Run \`npm install -g ${name}\`.`);
  }
}
