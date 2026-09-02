import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// The browser hand-off is simulated: openBrowser reads the authorize URL and
// hits the CLI's own loopback callback (via real fetch), driving the flow.
vi.mock("../src/lib/browser.js", () => ({
  openBrowser: vi.fn(async (authorizeUrl: string) => {
    const url = new URL(authorizeUrl);
    const redirect = url.searchParams.get("redirect_uri")!;
    const state = url.searchParams.get("state")!;
    await fetch(`${redirect}?code=THECODE&state=${state}`);
  }),
}));

// The code→token exchange is stubbed (the real server is tested separately).
vi.mock("../src/lib/api.js", () => ({
  exchangeCode: vi.fn(async (_url: string, code: string) => {
    if (code !== "THECODE") throw new Error("unexpected code");
    return { token: "lb_pat_minted", user: { email: "ada@example.com" } };
  }),
}));

import { login } from "../src/commands/login.js";
import { loadToken } from "../src/lib/credentials.js";

beforeEach(async () => {
  const dir = await mkdtemp(join(tmpdir(), "lb-login-"));
  process.env.LB_CREDENTIALS_FILE = join(dir, "credentials.json");
});

afterEach(() => {
  delete process.env.LB_CREDENTIALS_FILE;
  vi.clearAllMocks();
});

describe("login", () => {
  it("runs the loopback flow and stores the minted token", async () => {
    const result = await login({ url: "http://server.test" }, "laptop");

    expect(result.user).toBe("ada@example.com");
    expect(await loadToken("http://server.test")).toBe("lb_pat_minted");
  });
});
