import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { ConfigError, loadFile, resolveConfigs } from "../src/lib/config.js";

let cwd: string;
let dir: string;

beforeEach(async () => {
  cwd = process.cwd();
  dir = await mkdtemp(join(tmpdir(), "lb-cfg-"));
  process.chdir(dir);
  process.env.LB_TOKEN = "lb_pat_test";
  process.env.LB_CREDENTIALS_FILE = join(dir, "creds.json"); // isolate from real creds
  delete process.env.LB_PROJECT;
  delete process.env.LB_URL;
});

afterEach(() => {
  process.chdir(cwd);
  delete process.env.LB_TOKEN;
  delete process.env.LB_CREDENTIALS_FILE;
});

async function writeConfig(config: unknown): Promise<void> {
  await writeFile(join(dir, "language-bridge.json"), JSON.stringify(config));
  loadFile.clear(); // config resolution memoizes the file read per cwd
}

describe("resolveConfigs", () => {
  it("resolves every project in a projects list with per-slug default paths", async () => {
    await writeConfig({ url: "http://s", projects: [{ project: "main-app" }, { project: "marketing", namespaces: ["landing"] }] });

    const configs = await resolveConfigs({});
    expect(configs.map((c) => c.project)).toEqual(["main-app", "marketing"]);
    expect(configs[0]!.out).toBe("src/@types/main-app.d.ts");
    expect(configs[0]!.jsonDir).toBe(".language-bridge/main-app");
    expect(configs[1]!.namespaces).toEqual(["landing"]);
  });

  it("--project narrows to one entry keeping its overrides", async () => {
    await writeConfig({ projects: [{ project: "main-app", out: "custom.d.ts" }, { project: "marketing" }] });

    const configs = await resolveConfigs({ project: "main-app" });
    expect(configs).toHaveLength(1);
    expect(configs[0]!.out).toBe("custom.d.ts");
  });

  it("keeps legacy single-project defaults", async () => {
    await writeConfig({ project: "solo" });

    const configs = await resolveConfigs({});
    expect(configs).toHaveLength(1);
    expect(configs[0]!.out).toBe("src/@types/resources.d.ts");
    expect(configs[0]!.jsonDir).toBe(".language-bridge/locales");
  });

  it("rejects a per-project flag when several projects resolve", async () => {
    await writeConfig({ projects: [{ project: "a" }, { project: "b" }] });
    await expect(resolveConfigs({ out: "x.d.ts" })).rejects.toBeInstanceOf(ConfigError);
  });

  it("lets --project stand alone when the slug isn't listed", async () => {
    await writeConfig({ projects: [{ project: "a" }] });
    const configs = await resolveConfigs({ project: "ghost" });
    expect(configs).toHaveLength(1);
    expect(configs[0]!.project).toBe("ghost");
  });

  it("errors without a token or without any project", async () => {
    await writeConfig({ project: "solo" });
    delete process.env.LB_TOKEN;
    await expect(resolveConfigs({})).rejects.toBeInstanceOf(ConfigError);

    process.env.LB_TOKEN = "lb_pat_test";
    await writeConfig({ url: "http://s" });
    await expect(resolveConfigs({})).rejects.toBeInstanceOf(ConfigError);
  });
});
