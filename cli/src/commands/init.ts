import { access, writeFile } from "node:fs/promises";
import { safely } from "1o1-utils";
import { fetchUser } from "../lib/api.js";
import type { ServerConfig } from "../lib/config.js";

export const CONFIG_FILE = "language-bridge.json";

export interface InitResult {
  path: string;
  created: boolean;
  projects: string[];
}

// Scaffold a starter config in the current directory. When a stored login can
// reach the server, the real accessible project slugs are prefilled; otherwise a
// placeholder slug shows the shape to fill in. Never overwrites without force.
export async function init(server: ServerConfig, force = false): Promise<InitResult> {
  const [exists] = await safely(access)(CONFIG_FILE);
  if (exists === undefined && !force) {
    return { path: CONFIG_FILE, created: false, projects: [] };
  }

  const projects = await discoverProjects(server);
  const slugs = projects.length > 0 ? projects : ["your-project-slug"];

  const config = {
    url: server.url,
    projects: slugs.map((slug) => ({ project: slug })),
  };
  await writeFile(CONFIG_FILE, `${JSON.stringify(config, null, 2)}\n`);
  return { path: CONFIG_FILE, created: true, projects };
}

// The projects the stored/passed token can reach — empty when logged out or the
// server is unreachable (init still scaffolds, just with a placeholder).
async function discoverProjects(server: ServerConfig): Promise<string[]> {
  if (!server.token) return [];
  const [, response] = await safely(fetchUser)(server.url, server.token);
  return response?.projects ?? [];
}
