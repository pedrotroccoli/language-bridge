import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("../src/lib/api.js", () => ({
  fetchUser: vi.fn(async () => ({ user: { email: "a@b.com" }, projects: ["main-app"] })),
  fetchExport: vi.fn(async (config: { project: string }) => ({
    project: config.project,
    locale: "en",
    is_source: true,
    namespaces: { common: {}, auth: {} },
    available_locales: ["en", "pt-BR"],
    source_locale: "en",
  })),
}));

import { validateConfig } from "../src/commands/validate-config.js";
import type { ResolvedConfig } from "../src/lib/config.js";

function config(over: Partial<ResolvedConfig> = {}): ResolvedConfig {
  return {
    token: "lb_pat_x",
    url: "http://server.test",
    project: "main-app",
    out: "o.d.ts",
    jsonDir: ".",
    includeDrafts: false,
    params: true,
    keepJson: false,
    ...over,
  };
}

afterEach(() => vi.clearAllMocks());

describe("validate", () => {
  it("passes a project that exists with a valid locale and namespaces", async () => {
    const [result] = await validateConfig([config({ locale: "en", namespaces: ["common"] })]);
    expect(result!.ok).toBe(true);
    expect(result!.problems).toEqual([]);
  });

  it("flags a project the token cannot reach", async () => {
    const [result] = await validateConfig([config({ project: "ghost" })]);
    expect(result!.ok).toBe(false);
    expect(result!.problems[0]).toMatch(/not found or not accessible/);
  });

  it("flags an unknown locale and namespace", async () => {
    const [result] = await validateConfig([config({ locale: "de", namespaces: ["nope"] })]);
    expect(result!.ok).toBe(false);
    expect(result!.problems.some((p) => p.includes('locale "de"'))).toBe(true);
    expect(result!.problems.some((p) => p.includes('namespace "nope"'))).toBe(true);
  });
});
