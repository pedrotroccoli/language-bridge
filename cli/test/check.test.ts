import { describe, expect, it, vi } from "vitest";

vi.mock("../src/lib/api.js", () => ({
  fetchExport: vi.fn(async (config: { includeDrafts: boolean }) => ({
    locale: "en",
    source_locale: "en",
    available_locales: ["en"],
    namespaces: config.includeDrafts
      ? { common: { greeting: "Hello", cta: { signup: "Join" } }, emails: { subject: "Hi" } }
      : { common: { greeting: "Hello" } },
  })),
}));

import { check } from "../src/commands/check.js";
import type { ResolvedConfig } from "../src/lib/config.js";

const config: ResolvedConfig = {
  token: "lb_pat_x",
  url: "http://server.test",
  project: "main-app",
  out: "o.d.ts",
  jsonDir: ".",
  includeDrafts: false,
  params: true,
  keepJson: false,
};

describe("check", () => {
  it("reports keys that exist only with drafts included", async () => {
    const result = await check(config);

    expect(result.ok).toBe(false);
    expect(result.unpublished).toEqual(["common:cta.signup", "emails:subject"]);
  });

  it("passes when the drafts export adds nothing", async () => {
    const { fetchExport } = await import("../src/lib/api.js");
    vi.mocked(fetchExport).mockResolvedValue({
      locale: "en",
      source_locale: "en",
      available_locales: ["en"],
      namespaces: { common: { greeting: "Hello" } },
    } as never);

    const result = await check(config);
    expect(result.ok).toBe(true);
    expect(result.unpublished).toEqual([]);
  });
});
