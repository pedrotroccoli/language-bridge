import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { push } from "../src/commands/push.js";
import type { ResolvedConfig } from "../src/lib/config.js";

function config(over: Partial<ResolvedConfig> = {}): ResolvedConfig {
  return {
    token: "tok",
    url: "http://server",
    project: "main-app",
    out: "out.d.ts",
    jsonDir: "",
    includeDrafts: false,
    params: true,
    keepJson: false,
    ...over,
  };
}

async function jsonDirWith(files: Record<string, unknown>): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), "lb-push-"));
  for (const [name, tree] of Object.entries(files)) {
    await writeFile(join(dir, `${name}.json`), JSON.stringify(tree));
  }
  return dir;
}

afterEach(() => vi.unstubAllGlobals());

describe("push chunking", () => {
  function bigTree(count: number): Record<string, string> {
    return Object.fromEntries(Array.from({ length: count }, (_, index) => [`key_${index}`, "v"]));
  }

  it("slices a >2000-entry push into sequential requests, merging counts and paths", async () => {
    let call = 0;
    const fetchMock = vi.fn(async () => {
      call += 1;
      return new Response(
        JSON.stringify({ status: "ok", locale: "en", session: "s", written: call === 1 ? 2000 : 1, playground_paths: [`p${call}`], preview_paths: ["shared"] }),
        { status: 200 },
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    const jsonDir = await jsonDirWith({ common: bigTree(2001) });
    const result = await push(config({ jsonDir, locale: "en", session: "s" }));

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(result.written).toBe(2001);
    expect(result.playground_paths).toEqual(["p1", "p2"]);
    expect(result.preview_paths).toEqual(["shared"]);
  });

  it("says what already landed when a later chunk fails", async () => {
    let call = 0;
    const fetchMock = vi.fn(async () => {
      call += 1;
      if (call === 2) return new Response("boom", { status: 500, statusText: "Internal Server Error" });
      return new Response(JSON.stringify({ status: "ok", locale: "en", session: "s", written: 2000 }), { status: 200 });
    });
    vi.stubGlobal("fetch", fetchMock);

    const jsonDir = await jsonDirWith({ common: bigTree(2001) });
    await expect(push(config({ jsonDir, locale: "en", session: "s" }))).rejects.toThrow(/part 2\/2 — 2000 draft\(s\).*re-running the same push is safe/);
  });
});

describe("push", () => {
  it("POSTs the local namespaces to the import endpoint with bearer auth", async () => {
    const fetchMock = vi.fn(
      async () => new Response(JSON.stringify({ status: "ok", locale: "en", written: 1 }), { status: 200 }),
    );
    vi.stubGlobal("fetch", fetchMock);

    const jsonDir = await jsonDirWith({ common: { home: { title: "Welcome" } } });
    const result = await push(config({ jsonDir, locale: "en", session: "feat/x" }));

    expect(result.written).toBe(1);
    const [url, init] = fetchMock.mock.calls[0]!;
    expect(String(url)).toBe("http://server/api/v1/projects/main-app/import");
    expect(init?.method).toBe("POST");
    expect((init?.headers as Record<string, string>).Authorization).toBe("Bearer tok");
    expect(JSON.parse(init?.body as string)).toEqual({
      locale: "en",
      session: "feat/x",
      namespaces: { common: { home: { title: "Welcome" } } },
    });
  });

  it("defaults the session to the current git branch", async () => {
    const fetchMock = vi.fn(
      async () => new Response(JSON.stringify({ status: "ok", locale: "en", session: "", written: 1 }), { status: 200 }),
    );
    vi.stubGlobal("fetch", fetchMock);

    const jsonDir = await jsonDirWith({ common: { a: "b" } });
    await push(config({ jsonDir, locale: "en" })); // no explicit session

    const body = JSON.parse(fetchMock.mock.calls[0]![1]?.body as string);
    expect(typeof body.session).toBe("string"); // resolved from git branch (or "")
  });

  it("discovers the source locale when --locale is omitted", async () => {
    const fetchMock = vi.fn(async (url: string | URL) => {
      if (String(url).includes("/export")) {
        return new Response(JSON.stringify({ source_locale: "pt-BR", namespaces: {}, available_locales: [] }), { status: 200 });
      }
      return new Response(JSON.stringify({ status: "ok", locale: "pt-BR", written: 0 }), { status: 200 });
    });
    vi.stubGlobal("fetch", fetchMock);

    const jsonDir = await jsonDirWith({ common: { a: "b" } });
    await push(config({ jsonDir }));

    const importCall = fetchMock.mock.calls.find(([url]) => String(url).includes("/import"))!;
    expect(JSON.parse(importCall[1]?.body as string).locale).toBe("pt-BR");
  });

  it("surfaces a server error message", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("Only the source locale accepts proposals", { status: 422, statusText: "Unprocessable Entity" })),
    );
    const jsonDir = await jsonDirWith({ common: { a: "b" } });
    await expect(push(config({ jsonDir, locale: "pt-BR" }))).rejects.toThrow(/source locale/);
  });
});
