// Resolves config with precedence: CLI flags > env (LB_*) > cosmiconfig file
// (language-bridge.json / .language-bridgerc / "languageBridge" in package.json).
// The token additionally falls back to the stored `lb login` credential.
import { memo } from "1o1-utils";
import { cosmiconfig } from "cosmiconfig";
import { loadToken } from "./credentials.js";

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
  name?: string;
  verbose?: boolean;
  json?: boolean;
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

// Per-project overrides in a multi-project config. `project` (the slug) is
// required; everything else falls back to the top-level shared defaults, then to
// a per-slug default (so several projects never collide on one output path).
interface FileProjectConfig {
  project: string;
  locale?: string;
  namespaces?: string[];
  out?: string;
  jsonDir?: string;
  params?: boolean;
  session?: string;
}

// A config file must never carry the token — it is commonly committed, so the
// token comes only from --token or LB_TOKEN. Top-level fields are shared
// defaults; `projects` (a list) enables a monorepo consuming several projects.
interface FileConfig {
  url?: string;
  project?: string;
  projects?: FileProjectConfig[];
  locale?: string;
  namespaces?: string[];
  out?: string;
  jsonDir?: string;
  includeDrafts?: boolean;
  params?: boolean;
  session?: string;
}

// Memoized per working directory: resolveConfigs consults the file both
// directly and via resolveServer, and without the cache cosmiconfig would walk
// the disk twice per command. Exported so tests that rewrite the config file
// mid-process can loadFile.clear().
export const loadFile: (() => Promise<FileConfig>) & { clear: () => void } = memo({
  key: () => process.cwd(),
  fn: async (): Promise<FileConfig> => {
    // Explicit searchPlaces so a bare `language-bridge.json` (the documented
    // form) is discovered — cosmiconfig's defaults only cover the .rc / .config
    // variants.
    const explorer = cosmiconfig("language-bridge", {
      searchPlaces: [
        "package.json",
        "language-bridge.json",
        ".language-bridgerc",
        ".language-bridgerc.json",
        ".language-bridgerc.yaml",
        ".language-bridgerc.yml",
        "language-bridge.config.js",
        "language-bridge.config.cjs",
      ],
    });
    const result = await explorer.search();
    return (result?.config as FileConfig | undefined) ?? {};
  },
});

function firstDefined<T>(...values: (T | undefined)[]): T | undefined {
  return values.find((value) => value !== undefined);
}

class ConfigError extends Error {}

// The server URL plus whatever token we can find (flag > env > stored login).
// Used by commands that don't need a project — login/logout/whoami.
export interface ServerConfig {
  url: string;
  token?: string;
}

export async function resolveServer(options: CliOptions): Promise<ServerConfig> {
  const file = await loadFile();
  const env = process.env;
  const url = firstDefined(options.url, env.LB_URL, file.url) ?? DEFAULT_URL;
  const token = firstDefined(options.token, env.LB_TOKEN) ?? (await loadToken(url));
  return { url, token };
}

// Flags that describe a single project's output; ambiguous across many.
const PER_PROJECT_FLAGS: [keyof CliOptions, string][] = [
  ["out", "--out"],
  ["jsonDir", "--json-dir"],
  ["locale", "--locale"],
  ["namespace", "--namespace"],
];

// Resolve one project's full config. Single-project callers get exactly this.
export async function resolveConfig(options: CliOptions): Promise<ResolvedConfig> {
  const configs = await resolveConfigs(options); // never empty — throws otherwise
  return configs[0]!;
}

// Resolve every project a command should act on. A config `projects` list makes
// it multi-project (a monorepo); `--project`/LB_PROJECT narrows to one. Without
// a selector, all configured projects run.
export async function resolveConfigs(options: CliOptions): Promise<ResolvedConfig[]> {
  const file = await loadFile();
  const env = process.env;
  const { url, token } = await resolveServer(options);

  if (!token) throw new ConfigError("Missing token. Run `lb login`, pass --token, or set LB_TOKEN.");

  const entries = projectEntries(file, firstDefined(options.project, env.LB_PROJECT));
  if (entries.length === 0) throw new ConfigError("Missing project. Add `projects` to your config, pass --project, or set LB_PROJECT.");

  const multi = (file.projects?.length ?? 0) > 0;
  if (entries.length > 1) {
    const offending = PER_PROJECT_FLAGS.find(([key]) => options[key] !== undefined);
    if (offending) throw new ConfigError(`${offending[1]} is ambiguous across ${entries.length} projects — set it per-project in the config.`);
  }

  return entries.map((entry) => buildConfig({ entry, file, options, env, url, token, multi }));
}

// The project entries to act on, applying an optional slug selector.
function projectEntries(file: FileConfig, selector?: string): FileProjectConfig[] {
  const configured = file.projects?.length
    ? file.projects
    : file.project
      ? [ { project: file.project } ]
      : [];

  if (!selector) return configured;

  // A selector picks the matching configured entry (keeping its overrides), or
  // stands alone when the slug isn't listed.
  return [ configured.find((entry) => entry.project === selector) ?? { project: selector } ];
}

interface BuildInput {
  entry: FileProjectConfig;
  file: FileConfig;
  options: CliOptions;
  env: NodeJS.ProcessEnv;
  url: string;
  token: string;
  multi: boolean;
}

function buildConfig({ entry, file, options, env, url, token, multi }: BuildInput): ResolvedConfig {
  const slug = entry.project;
  const namespaces = firstDefined(options.namespace, entry.namespaces, file.namespaces);
  const defaultOut = multi ? `src/@types/${slug}.d.ts` : DEFAULT_OUT;
  const defaultJsonDir = multi ? `.language-bridge/${slug}` : ".language-bridge/locales";

  return {
    token,
    url,
    project: slug,
    locale: firstDefined(options.locale, entry.locale, file.locale),
    namespaces: namespaces && namespaces.length > 0 ? namespaces : undefined,
    out: firstDefined(options.out, entry.out, file.out) ?? defaultOut,
    jsonDir: firstDefined(options.jsonDir, entry.jsonDir, file.jsonDir) ?? defaultJsonDir,
    includeDrafts: firstDefined(options.includeDrafts, file.includeDrafts) ?? false,
    params: firstDefined(options.params, entry.params, file.params) ?? true,
    keepJson: options.keepJson ?? false,
    session: firstDefined(options.session, env.LB_SESSION, entry.session, file.session),
  };
}

export { ConfigError };
