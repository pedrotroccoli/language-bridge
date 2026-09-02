// Thin client for the Language Bridge endpoints the CLI consumes:
//   GET  /api/v1/projects/:project/export?locale=&include_drafts=
//   POST /api/v1/projects/:project/import   { locale, namespaces }
import type { ResolvedConfig } from "./config.js";
import { debug } from "./debug.js";
import type { ExchangeResponse, ExportResponse, ImportResponse, Namespaces, WhoamiResponse } from "./types.js";

export async function fetchExport(config: ResolvedConfig): Promise<ExportResponse> {
  const url = new URL(`/api/v1/projects/${encodeURIComponent(config.project)}/export`, config.url);
  if (config.locale) url.searchParams.set("locale", config.locale);
  if (config.includeDrafts) url.searchParams.set("include_drafts", "1");

  const response = await send(config, url, { method: "GET" });
  await ensureOk(response, "Export");
  return (await response.json()) as ExportResponse;
}

// Push source-locale values as reviewable proposals (never live). The body is
// the nested export shape; the server flattens and skips blank leaves. `session`
// (git branch or chat) keeps parallel work streams from clobbering each other.
export async function pushProposals(config: ResolvedConfig, locale: string, session: string, namespaces: Namespaces): Promise<ImportResponse> {
  const url = new URL(`/api/v1/projects/${encodeURIComponent(config.project)}/import`, config.url);
  const response = await send(config, url, {
    method: "POST",
    body: JSON.stringify({ locale, session, namespaces }),
    headers: { "Content-Type": "application/json" },
  });
  await ensureOk(response, "Import");
  return (await response.json()) as ImportResponse;
}

// Shared request: bearer auth + a friendly network error.
async function send(config: ResolvedConfig, url: URL, init: RequestInit): Promise<Response> {
  debug(`${init.method ?? "GET"} ${url}`);
  try {
    const response = await fetch(url, {
      ...init,
      headers: { Authorization: `Bearer ${config.token}`, Accept: "application/json", ...init.headers },
    });
    debug(`${response.status} ${response.statusText} ${url.pathname}`);
    return response;
  } catch (cause) {
    throw new Error(`Could not reach ${config.url}: ${(cause as Error).message}`);
  }
}

async function ensureOk(response: Response, label: string): Promise<void> {
  if (response.ok) return;
  const detail = await response.text().catch(() => "");
  const message = detail.trim() ? ` — ${detail.trim()}` : "";
  // An invalid token is the one failure the user can always self-serve.
  const hint = response.status === 401 ? " Token invalid or revoked — run `lb login`." : "";
  throw new Error(`${label} request failed: ${response.status} ${response.statusText}${message}${hint}`);
}

// Exchange a one-time login code (from the loopback callback) for a token.
export async function exchangeCode(url: string, code: string): Promise<ExchangeResponse> {
  const endpoint = new URL("/api/v1/cli/token", url);
  debug(`POST ${endpoint}`);
  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ code }),
    });
  } catch (cause) {
    throw new Error(`Could not reach ${url}: ${(cause as Error).message}`);
  }
  await ensureOk(response, "Token exchange");
  return (await response.json()) as ExchangeResponse;
}

// Resolve a token to its user + accessible projects (`lb whoami`).
export async function fetchUser(url: string, token: string): Promise<WhoamiResponse> {
  const endpoint = new URL("/api/v1/user", url);
  debug(`GET ${endpoint}`);
  let response: Response;
  try {
    response = await fetch(endpoint, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    });
  } catch (cause) {
    throw new Error(`Could not reach ${url}: ${(cause as Error).message}`);
  }
  await ensureOk(response, "Whoami");
  return (await response.json()) as WhoamiResponse;
}
