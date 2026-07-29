// Thin client for the Language Bridge export endpoint the CLI consumes:
//   GET /api/v1/projects/:project/export?locale=&include_drafts=
import type { ResolvedConfig } from "./config.js";
import type { ExportResponse } from "./types.js";

export async function fetchExport(config: ResolvedConfig): Promise<ExportResponse> {
  const url = new URL(`/api/v1/projects/${encodeURIComponent(config.project)}/export`, config.url);
  if (config.locale) url.searchParams.set("locale", config.locale);
  if (config.includeDrafts) url.searchParams.set("include_drafts", "1");

  let response: Response;
  try {
    response = await fetch(url, {
      headers: { Authorization: `Bearer ${config.token}`, Accept: "application/json" },
    });
  } catch (cause) {
    throw new Error(`Could not reach ${config.url}: ${(cause as Error).message}`);
  }

  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    const message = detail.trim() ? ` — ${detail.trim()}` : "";
    throw new Error(`Export request failed: ${response.status} ${response.statusText}${message}`);
  }

  return (await response.json()) as ExportResponse;
}
