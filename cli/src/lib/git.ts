import { execFile } from "node:child_process";
import { promisify } from "node:util";

const run = promisify(execFile);

// Current git branch, used as the default push session so parallel branches keep
// separate proposals. Undefined outside a repo or on a detached HEAD.
export async function gitBranch(): Promise<string | undefined> {
  try {
    const { stdout } = await run("git", ["rev-parse", "--abbrev-ref", "HEAD"]);
    const branch = stdout.trim();
    return branch && branch !== "HEAD" ? branch : undefined;
  } catch {
    return undefined;
  }
}
