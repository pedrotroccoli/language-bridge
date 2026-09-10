// Thin client for the Language Bridge endpoints the CLI consumes:
//   GET  /api/v1/projects/:project/export?locale=&include_drafts=
//   POST /api/v1/projects/:project/import   { locale, namespaces }
import type { ResolvedConfig } from "./config.js";
import { debug } from "./debug.js";
import { redactHeaders } from "./headers.js";
import type { ExchangeResponse, ExportResponse, ImportResponse, Namespaces, WhoamiResponse } from "./types.js";

export async function fetchExport(config: ResolvedConfig): Promise<ExportResponse> {
  const url = new URL(`/api/v1/projects/${encodeURIComponent(config.project)}/export`, config.url);
  if (config.locale) url.searchParams.set("locale", config.locale);
  if (config.includeDrafts) url.searchParams.set("include_drafts", "1");

  const response = await send(config, url, { method: "GET" });
  return readJson<ExportResponse>(response, "Export");
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
  return readJson<ImportResponse>(response, "Import");
}

// Shared request: custom headers under, the CLI's own on top (a custom header
// can never clobber Authorization/Accept/Content-Type), plus a friendly
// network error.
async function send(config: ResolvedConfig, url: URL, init: RequestInit): Promise<Response> {
  const custom = config.headers ?? {};
  debug(`${init.method ?? "GET"} ${url}`);
  if (Object.keys(custom).length > 0) debug(`custom headers: ${redactHeaders(custom)}`);
  try {
    const response = await fetch(url, {
      ...init,
      headers: { ...custom, Authorization: `Bearer ${config.token}`, Accept: "application/json", ...init.headers },
    });
    debug(`${response.status} ${response.statusText} ${url.pathname}`);
    return response;
  } catch (cause) {
    throw new Error(`Could not reach ${config.url}: ${(cause as Error).message}`);
  }
}

// Status check + JSON parse in one place, with the auth-proxy case made
// readable: a proxy (Cloudflare Access etc.) intercepts the request and
// answers with its HTML login page, which JSON.parse would otherwise turn
// into `Unexpected token '<'`.
export async function readJson<T>(response: Response, label: string): Promise<T> {
  const contentType = response.headers.get("content-type") ?? "";
  const text = await response.text().catch(() => "");

  if (contentType.includes("text/html") || text.trimStart().startsWith("<")) {
    throw new Error(`${label}: server returned HTML, not JSON — the endpoint may be behind an auth proxy (Cloudflare Access). Pass the required headers via -H or LB_HEADERS.`);
  }
  if (!response.ok) {
    const message = text.trim() ? ` — ${text.trim()}` : "";
    // An invalid token is the one failure the user can always self-serve.
    const hint = response.status === 401 ? " Token invalid or revoked — run `lb login`." : "";
    throw new Error(`${label} request failed: ${response.status} ${response.statusText}${message}${hint}`);
  }
  return JSON.parse(text) as T;
}

// Exchange a one-time login code (from the loopback callback) for a token.
export async function exchangeCode(url: string, code: string, headers: Record<string, string> = {}): Promise<ExchangeResponse> {
  const endpoint = new URL("/api/v1/cli/token", url);
  debug(`POST ${endpoint}`);
  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ code }),
    });
  } catch (cause) {
    throw new Error(`Could not reach ${url}: ${(cause as Error).message}`);
  }
  return readJson<ExchangeResponse>(response, "Token exchange");
}

// Resolve a token to its user + accessible projects (`lb whoami`).
export async function fetchUser(url: string, token: string, headers: Record<string, string> = {}): Promise<WhoamiResponse> {
  const endpoint = new URL("/api/v1/user", url);
  debug(`GET ${endpoint}`);
  let response: Response;
  try {
    response = await fetch(endpoint, {
      headers: { ...headers, Authorization: `Bearer ${token}`, Accept: "application/json" },
    });
  } catch (cause) {
    throw new Error(`Could not reach ${url}: ${(cause as Error).message}`);
  }
  return readJson<WhoamiResponse>(response, "Whoami");
}
