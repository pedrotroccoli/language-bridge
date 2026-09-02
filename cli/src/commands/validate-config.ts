import { fetchExport, fetchUser } from "../lib/api.js";
import type { ResolvedConfig } from "../lib/config.js";

export interface ProjectValidation {
  project: string;
  ok: boolean;
  problems: string[];
}

// Validate resolved project configs against the server: the token works, each
// project exists and is accessible, and any configured locale/namespaces are
// real. One identity call proves the token, then one export per project checks
// its parameters. Never throws per project — problems are collected and returned.
export async function validateConfig(configs: ResolvedConfig[]): Promise<ProjectValidation[]> {
  const { url, token } = configs[0]!;
  const { projects: accessible } = await fetchUser(url, token);
  const reachable = new Set(accessible);

  const results: ProjectValidation[] = [];
  for (const config of configs) {
    const problems: string[] = [];

    if (!reachable.has(config.project)) {
      problems.push(`project "${config.project}" not found or not accessible by this token`);
      results.push({ project: config.project, ok: false, problems });
      continue;
    }

    try {
      // Fetch the source bundle (locale omitted) to learn the real locales and
      // namespaces, then check the configured ones against it.
      const exported = await fetchExport({ ...config, locale: undefined });
      if (config.locale && !exported.available_locales.includes(config.locale)) {
        problems.push(`locale "${config.locale}" is not one of: ${exported.available_locales.join(", ")}`);
      }
      const known = new Set(Object.keys(exported.namespaces));
      for (const ns of config.namespaces ?? []) {
        if (!known.has(ns)) problems.push(`namespace "${ns}" does not exist`);
      }
    } catch (error) {
      problems.push(error instanceof Error ? error.message : String(error));
    }

    results.push({ project: config.project, ok: problems.length === 0, problems });
  }
  return results;
}
