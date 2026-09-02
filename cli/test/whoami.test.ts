import { afterEach, describe, expect, it, vi } from "vitest";
import { whoami } from "../src/commands/whoami.js";

afterEach(() => vi.unstubAllGlobals());

describe("whoami", () => {
  it("resolves the token to its user and projects", async () => {
    const fetchMock = vi.fn(
      async () =>
        new Response(JSON.stringify({ user: { email: "ada@example.com" }, projects: ["main-app"] }), { status: 200 }),
    );
    vi.stubGlobal("fetch", fetchMock);

    const result = await whoami({ url: "http://server.test", token: "lb_pat_x" });
    expect(result.user.email).toBe("ada@example.com");
    expect(result.projects).toEqual(["main-app"]);

    const [url, init] = fetchMock.mock.calls[0]!;
    expect(String(url)).toBe("http://server.test/api/v1/user");
    expect((init?.headers as Record<string, string>).Authorization).toBe("Bearer lb_pat_x");
  });

  it("errors when not logged in", async () => {
    await expect(whoami({ url: "http://server.test" })).rejects.toThrow(/lb login/);
  });
});
