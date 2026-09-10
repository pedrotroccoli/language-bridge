import { afterEach, describe, expect, it, vi } from "vitest";
import { fetchExport, fetchUser, readJson } from "../src/lib/api.js";
import type { ResolvedConfig } from "../src/lib/config.js";

function config(overrides: Partial<ResolvedConfig> = {}): ResolvedConfig {
  return {
    token: "tok",
    url: "http://server.test",
    headers: {},
    project: "demo",
    out: "out.d.ts",
    jsonDir: ".language-bridge/locales",
    includeDrafts: false,
    params: true,
    keepJson: false,
    ...overrides,
  };
}

function jsonResponse(body: unknown): Response {
  return new Response(JSON.stringify(body), { status: 200, headers: { "content-type": "application/json" } });
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("custom headers", () => {
  it("sends them on requests, without touching the CLI's own headers", async () => {
    const fetchMock = vi.fn(async () => jsonResponse({ namespaces: {} }));
    vi.stubGlobal("fetch", fetchMock);

    await fetchExport(config({ headers: { "CF-Access-Client-Id": "id", "CF-Access-Client-Secret": "secret" } }));

    const [, init] = fetchMock.mock.calls[0] as unknown as [URL, RequestInit];
    const headers = init.headers as Record<string, string>;
    expect(headers["CF-Access-Client-Id"]).toBe("id");
    expect(headers["CF-Access-Client-Secret"]).toBe("secret");
    expect(headers.Authorization).toBe("Bearer tok");
    expect(headers.Accept).toBe("application/json");
  });

  it("never lets a custom header clobber Authorization", async () => {
    const fetchMock = vi.fn(async () => jsonResponse({ namespaces: {} }));
    vi.stubGlobal("fetch", fetchMock);

    await fetchExport(config({ headers: { Authorization: "Bearer forged" } }));

    const [, init] = fetchMock.mock.calls[0] as unknown as [URL, RequestInit];
    expect((init.headers as Record<string, string>).Authorization).toBe("Bearer tok");
  });

  it("drops reserved names regardless of casing — no duplicate header via append", async () => {
    const fetchMock = vi.fn(async () => jsonResponse({ namespaces: {} }));
    vi.stubGlobal("fetch", fetchMock);

    await fetchExport(config({ headers: { authorization: "Bearer forged", "content-type": "text/evil", ACCEPT: "text/html" } }));

    const [, init] = fetchMock.mock.calls[0] as unknown as [URL, RequestInit];
    const headers = init.headers as Record<string, string>;
    expect(headers.authorization).toBeUndefined();
    expect(headers["content-type"]).toBeUndefined();
    expect(headers.ACCEPT).toBeUndefined();
    expect(headers.Authorization).toBe("Bearer tok");
    expect(headers.Accept).toBe("application/json");
  });

  it("rides along on the whoami/identity call", async () => {
    const fetchMock = vi.fn(async () => jsonResponse({ user: { email: "a@b.c" }, projects: [] }));
    vi.stubGlobal("fetch", fetchMock);

    await fetchUser("http://server.test", "tok", { "X-Proxy": "yes" });

    const [, init] = fetchMock.mock.calls[0] as unknown as [URL, RequestInit];
    expect((init.headers as Record<string, string>)["X-Proxy"]).toBe("yes");
  });
});

describe("readJson", () => {
  it("turns an HTML response into a readable auth-proxy error", async () => {
    const response = new Response("<!DOCTYPE html><html>login</html>", {
      status: 200,
      headers: { "content-type": "text/html; charset=utf-8" },
    });
    await expect(readJson(response, "Export")).rejects.toThrow(/auth proxy \(Cloudflare Access\)/);
  });

  it("detects HTML by body shape even without a content-type", async () => {
    const response = new Response("  <html>blocked</html>", { status: 200 });
    await expect(readJson(response, "Export")).rejects.toThrow(/HTML, not JSON/);
  });

  it("does not blame the proxy for the app's own HTML error page", async () => {
    const response = new Response("<html>500</html>", {
      status: 500,
      statusText: "Internal Server Error",
      headers: { "content-type": "text/html" },
    });
    const error = await readJson(response, "Export").catch((cause: Error) => cause);
    expect((error as Error).message).toContain("status 500");
    expect((error as Error).message).not.toContain("auth proxy");
  });

  it("still reports plain non-ok responses with status and detail", async () => {
    const response = new Response("nope", { status: 403, statusText: "Forbidden" });
    await expect(readJson(response, "Export")).rejects.toThrow(/403 Forbidden — nope/);
  });

  it("parses ordinary JSON untouched", async () => {
    await expect(readJson<{ ok: boolean }>(jsonResponse({ ok: true }), "Export")).resolves.toEqual({ ok: true });
  });
});
