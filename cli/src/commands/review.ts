import { openBrowser } from "../lib/browser.js";
import type { ResolvedConfig } from "../lib/config.js";
import { gitBranch } from "../lib/git.js";

// Build the review URL for a project's draft translations, filtered to the push
// session (given, or the current git branch — matching `lb push`).
export async function reviewUrl(config: ResolvedConfig): Promise<string> {
  const session = config.session ?? (await gitBranch()) ?? "";
  const url = new URL(`/projects/${encodeURIComponent(config.project)}/review`, config.url);
  if (session) url.searchParams.set("session", session);
  return url.toString();
}

// Open the review page (the editor filtered to this session's drafts) in the
// browser. Returns the URL for logging.
export async function review(config: ResolvedConfig): Promise<string> {
  const target = await reviewUrl(config);
  await openBrowser(target);
  return target;
}
