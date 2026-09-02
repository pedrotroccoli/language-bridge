// A translation tree as returned by the server: nested objects with string leaves.
export type TranslationTree = { [key: string]: TranslationTree | string };

// namespace name -> its nested tree. This is the `namespaces` field of the
// export API response and the input the emitter turns into TypeScript.
export type Namespaces = Record<string, TranslationTree>;

// Shape of GET /api/v1/projects/:slug/export.
export interface ExportResponse {
  project: string;
  locale: string;
  is_source: boolean;
  namespaces: Namespaces;
  available_locales: string[];
  source_locale: string | null;
}

// Shape of POST /api/v1/projects/:slug/import.
export interface ImportResponse {
  status: string;
  locale: string;
  session: string;
  written: number;
  // Storage keys of the session's materialized preview JSON (one per
  // namespace), for pointing a frontend preview at the connected storage.
  preview_paths?: string[];
  // Storage keys of the playground JSON (published + every draft) — a dev
  // environment points its i18n loadPath here; prod points at the published paths.
  playground_paths?: string[];
}

// Shape of POST /api/v1/cli/token (login code exchange).
export interface ExchangeResponse {
  token: string;
  user?: { email: string; name?: string };
}

// Shape of GET /api/v1/user (lb whoami).
export interface WhoamiResponse {
  user: { email: string; name?: string };
  projects: string[];
}
