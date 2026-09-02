import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { CONFIG_FILE, init } from "../src/commands/init.js";

let cwd: string;
let dir: string;

beforeEach(async () => {
  cwd = process.cwd();
  dir = await mkdtemp(join(tmpdir(), "lb-init-"));
  process.chdir(dir);
});

afterEach(() => {
  process.chdir(cwd);
});

describe("init", () => {
  it("scaffolds a placeholder config when logged out", async () => {
    const result = await init({ url: "http://localhost:3000" });

    expect(result.created).toBe(true);
    const config = JSON.parse(await readFile(CONFIG_FILE, "utf8"));
    expect(config).toEqual({
      url: "http://localhost:3000",
      projects: [{ project: "your-project-slug" }],
    });
  });

  it("refuses to overwrite an existing config without force", async () => {
    await writeFile(CONFIG_FILE, `{"url":"http://keep"}`);

    const result = await init({ url: "http://localhost:3000" });

    expect(result.created).toBe(false);
    expect(JSON.parse(await readFile(CONFIG_FILE, "utf8"))).toEqual({ url: "http://keep" });
  });

  it("overwrites with force", async () => {
    await writeFile(CONFIG_FILE, `{"url":"http://old"}`);

    const result = await init({ url: "http://new" }, true);

    expect(result.created).toBe(true);
    expect(JSON.parse(await readFile(CONFIG_FILE, "utf8")).url).toBe("http://new");
  });

  it("falls back to a placeholder when the server is unreachable", async () => {
    const result = await init({ url: "http://127.0.0.1:1", token: "lb_pat_x" });

    expect(result.created).toBe(true);
    expect(result.projects).toEqual([]);
    const config = JSON.parse(await readFile(CONFIG_FILE, "utf8"));
    expect(config.projects).toEqual([{ project: "your-project-slug" }]);
  });
});
