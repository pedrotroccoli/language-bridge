import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { renderInstructions, writeInstructions } from "../src/commands/ai-instructions.js";
import type { ResolvedConfig } from "../src/lib/config.js";

const config: ResolvedConfig = {
  token: "tok",
  url: "http://server",
  project: "main-app",
  out: "out.d.ts",
  jsonDir: ".",
  includeDrafts: false,
  params: true,
  keepJson: false,
};

afterEach(() => vi.unstubAllGlobals());

describe("renderInstructions", () => {
  it("embeds the project's source locale and namespaces", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response(
            JSON.stringify({
              source_locale: "en",
              available_locales: ["en", "pt-BR"],
              namespaces: { common: {}, emails: {} },
            }),
            { status: 200 },
          ),
      ),
    );

    const md = await renderInstructions(config);
    expect(md).toContain("Project: **main-app**");
    expect(md).toContain("Source locale: `en`");
    expect(md).toContain("`common`");
    expect(md).toContain("`emails`");
    expect(md).toContain("`pt-BR`");
  });
});

describe("writeInstructions", () => {
  it("wraps the block in markers and is idempotent on re-run", async () => {
    const dir = await mkdtemp(join(tmpdir(), "lb-ai-"));
    const file = join(dir, "AGENTS.md");

    await writeInstructions(file, "# first");
    await writeInstructions(file, "# second");

    const content = await readFile(file, "utf8");
    expect(content.match(/<!-- lb:start -->/g)).toHaveLength(1);
    expect(content).toContain("# second");
    expect(content).not.toContain("# first");
  });

  it("preserves surrounding content outside the markers", async () => {
    const dir = await mkdtemp(join(tmpdir(), "lb-ai-"));
    const file = join(dir, "AGENTS.md");
    await writeFile(file, "# My repo\n\nHand-written notes.\n");

    await writeInstructions(file, "# lb block");

    const content = await readFile(file, "utf8");
    expect(content).toContain("Hand-written notes.");
    expect(content).toContain("# lb block");
  });
});
