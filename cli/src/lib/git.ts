import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { safely } from "1o1-utils";

const run = promisify(execFile);

// Current git branch, used as the default push session so parallel branches keep
// separate proposals. Undefined outside a repo or on a detached HEAD.
export async function gitBranch(): Promise<string | undefined> {
  const [, result] = await safely(() => run("git", ["rev-parse", "--abbrev-ref", "HEAD"]))();
  const branch = result?.stdout.trim();
  return branch && branch !== "HEAD" ? branch : undefined;
}
