// Resolves config with precedence: CLI flags > env (LB_*) > cosmiconfig file
// (language-bridge.json / .language-bridgerc / "languageBridge" in package.json).
import { cosmiconfig } from "cosmiconfig";

const DEFAULT_URL = "http://localhost:3000";
const DEFAULT_OUT = "src/@types/resources.d.ts";

// Options coming from the command line (all optional; undefined = not passed).
export interface CliOptions {
  token?: string;
  url?: string;
  project?: string;
  locale?: string;
  namespace?: string[];
  out?: string;
  jsonDir?: string;
  includeDrafts?: boolean;
  params?: boolean;
  keepJson?: boolean;
  write?: string | boolean;
  session?: string;
}

export interface ResolvedConfig {
  token: string;
  url: string;
  project: string;
  locale?: string;
  namespaces?: string[];
  out: string;
  jsonDir: string;
  includeDrafts: boolean;
  params: boolean;
  keepJson: boolean;
  session?: string;
}

// A config file must never carry the token — it is commonly committed, so the
// token comes only from --token or LB_TOKEN.
interface FileConfig {
  url?: string;
  project?: string;
  locale?: string;
  namespaces?: string[];
  out?: string;
  jsonDir?: string;
  includeDrafts?: boolean;
  params?: boolean;
  session?: string;
}

async function loadFile(): Promise<FileConfig> {
  const result = await cosmiconfig("language-bridge").search();
  return (result?.config as FileConfig | undefined) ?? {};
}

function firstDefined<T>(...values: (T | undefined)[]): T | undefined {
  return values.find((value) => value !== undefined);
}

class ConfigError extends Error {}

export async function resolveConfig(options: CliOptions): Promise<ResolvedConfig> {
  const file = await loadFile();
  const env = process.env;

  const token = firstDefined(options.token, env.LB_TOKEN);
  const project = firstDefined(options.project, env.LB_PROJECT, file.project);

  if (!token) throw new ConfigError("Missing token. Pass --token or set LB_TOKEN.");
  if (!project) throw new ConfigError("Missing project. Pass --project or set LB_PROJECT.");

  const namespaces = firstDefined(options.namespace, file.namespaces);

  return {
    token,
    project,
    url: firstDefined(options.url, env.LB_URL, file.url) ?? DEFAULT_URL,
    locale: firstDefined(options.locale, file.locale),
    namespaces: namespaces && namespaces.length > 0 ? namespaces : undefined,
    out: firstDefined(options.out, file.out) ?? DEFAULT_OUT,
    jsonDir: firstDefined(options.jsonDir, file.jsonDir) ?? ".language-bridge/locales",
    includeDrafts: firstDefined(options.includeDrafts, file.includeDrafts) ?? false,
    params: firstDefined(options.params, file.params) ?? true,
    keepJson: options.keepJson ?? false,
    session: firstDefined(options.session, env.LB_SESSION, file.session),
  };
}

export { ConfigError };
