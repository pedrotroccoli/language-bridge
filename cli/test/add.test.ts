import { afterEach, describe, expect, it, vi } from "vitest";
import { add } from "../src/commands/add.js";
import type { ResolvedConfig } from "../src/lib/config.js";

function config(over: Partial<ResolvedConfig> = {}): ResolvedConfig {
  return {
    token: "tok",
    url: "http://server",
    headers: {},
    project: "main-app",
    out: "out.d.ts",
    jsonDir: "",
    includeDrafts: false,
    params: true,
    keepJson: false,
    session: "feat/x",
    ...over,
  };
}

function stubServer(meta: { namespaces: Record<string, unknown>; source_locale: string }) {
  const fetchMock = vi.fn(async (url: URL | string) => {
    if (String(url).includes("/export")) {
      return new Response(JSON.stringify({ ...meta, available_locales: [meta.source_locale] }), { status: 200 });
    }
    return new Response(JSON.stringify({ status: "ok", locale: "en", session: "feat/x", written: 1 }), { status: 200 });
  });
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

afterEach(() => vi.unstubAllGlobals());

describe("add", () => {
  it("pushes one nested key to the project's only namespace, no files involved", async () => {
    const fetchMock = stubServer({ namespaces: { common: {} }, source_locale: "en" });

    const result = await add(config(), "home.title", "Welcome");

    expect(result.namespace).toBe("common");
    const importCall = fetchMock.mock.calls.find(([url]) => String(url).includes("/import"))!;
    const body = JSON.parse((importCall[1] as RequestInit).body as string) as { locale: string; namespaces: unknown };
    expect(body.locale).toBe("en");
    expect(body.namespaces).toEqual({ common: { home: { title: "Welcome" } } });
  });

  it("requires --namespace when the project has several", async () => {
    stubServer({ namespaces: { common: {}, marketing: {} }, source_locale: "en" });
    await expect(add(config(), "k", "v")).rejects.toThrow(/pass --namespace/);
  });

  it("honors --namespace and --locale", async () => {
    const fetchMock = stubServer({ namespaces: { common: {}, marketing: {} }, source_locale: "en" });

    const result = await add(config({ namespaces: ["marketing"], locale: "pt-BR" }), "cta", "Compre");

    expect(result.namespace).toBe("marketing");
    const importCall = fetchMock.mock.calls.find(([url]) => String(url).includes("/import"))!;
    const body = JSON.parse((importCall[1] as RequestInit).body as string) as { locale: string; namespaces: unknown };
    expect(body.locale).toBe("pt-BR");
    expect(body.namespaces).toEqual({ marketing: { cta: "Compre" } });
  });
});
