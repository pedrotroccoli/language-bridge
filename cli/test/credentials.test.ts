import { mkdtemp, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { credentialsPath, loadToken, removeToken, saveToken } from "../src/lib/credentials.js";

let dir: string;

beforeEach(async () => {
  dir = await mkdtemp(join(tmpdir(), "lb-creds-"));
  process.env.LB_CREDENTIALS_FILE = join(dir, "credentials.json");
});

afterEach(() => {
  delete process.env.LB_CREDENTIALS_FILE;
});

describe("credentials", () => {
  it("saves and loads a token per server URL", async () => {
    await saveToken("http://a.test", { token: "lb_pat_a", user: "a@x.com" });
    await saveToken("http://b.test", { token: "lb_pat_b" });

    expect(await loadToken("http://a.test")).toBe("lb_pat_a");
    expect(await loadToken("http://b.test")).toBe("lb_pat_b");
    expect(await loadToken("http://unknown.test")).toBeUndefined();
  });

  it("treats trailing slashes as the same host", async () => {
    await saveToken("http://a.test/", { token: "lb_pat_a" });
    expect(await loadToken("http://a.test")).toBe("lb_pat_a");
  });

  it("writes the file with 0600 permissions", async () => {
    await saveToken("http://a.test", { token: "lb_pat_a" });
    const mode = (await stat(credentialsPath())).mode & 0o777;
    expect(mode).toBe(0o600);
  });

  it("removes only the target host and reports whether anything changed", async () => {
    await saveToken("http://a.test", { token: "lb_pat_a" });
    await saveToken("http://b.test", { token: "lb_pat_b" });

    expect(await removeToken("http://a.test")).toBe(true);
    expect(await loadToken("http://a.test")).toBeUndefined();
    expect(await loadToken("http://b.test")).toBe("lb_pat_b");
    expect(await removeToken("http://a.test")).toBe(false);
  });
});
