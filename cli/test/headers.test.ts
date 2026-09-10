import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { HeaderError, parseHeader, parseHeaderList, redactHeaders, resolveHeaders } from "../src/lib/headers.js";

describe("parseHeader", () => {
  it("splits on the first colon only and trims both sides", () => {
    expect(parseHeader("  cf-access-token :  eyJhbGciOi:JIUzI1NiJ9  ")).toEqual(["cf-access-token", "eyJhbGciOi:JIUzI1NiJ9"]);
  });

  it("rejects a pair without a colon", () => {
    expect(() => parseHeader("not-a-header")).toThrow(HeaderError);
    expect(() => parseHeader("not-a-header")).toThrow(/expected "Name: Value"/);
  });

  it("rejects a pair with an empty name", () => {
    expect(() => parseHeader(": value")).toThrow(HeaderError);
  });

  it("allows an empty value", () => {
    expect(parseHeader("X-Empty:")).toEqual(["X-Empty", ""]);
  });

  it("rejects a name with invalid characters instead of failing later in fetch", () => {
    expect(() => parseHeader("X Foo: bar")).toThrow(HeaderError);
  });
});

describe("parseHeaderList", () => {
  it("splits comma-separated pairs when there are no newlines", () => {
    expect(parseHeaderList("A: 1,B: 2")).toEqual({ A: "1", B: "2" });
  });

  it("with newlines present, commas stay part of the value (cookies)", () => {
    expect(parseHeaderList("Cookie: a=1, b=2\nX-Foo: bar\n")).toEqual({ Cookie: "a=1, b=2", "X-Foo": "bar" });
  });
});

describe("resolveHeaders", () => {
  it("merges per-key with flag > env > config", async () => {
    const merged = await resolveHeaders({
      flags: ["X-Flag: from-flag", "X-Shared: flag-wins"],
      env: "X-Env: from-env\nX-Shared: env-loses",
      file: { "X-File": "from-file", "X-Shared": "file-loses", "X-Env": "file-loses" },
    });
    expect(merged).toEqual({
      "X-File": "from-file",
      "X-Env": "from-env",
      "X-Flag": "from-flag",
      "X-Shared": "flag-wins",
    });
  });

  it("treats names case-insensitively, keeping the winner's casing", async () => {
    const merged = await resolveHeaders({ flags: ["X-FOO: flag"], file: { "x-foo": "file" } });
    expect(merged).toEqual({ "X-FOO": "flag" });
  });

  it("returns an empty object when no source is set", async () => {
    await expect(resolveHeaders({})).resolves.toEqual({});
  });
});

describe("resolveHeaders with command values", () => {
  let dir: string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "lb-headers-"));
    process.env.LB_TRUSTED_FILE = join(dir, "trusted.json");
    process.env.LB_TRUST_HEADER_COMMANDS = "1";
  });

  afterEach(() => {
    delete process.env.LB_TRUSTED_FILE;
    delete process.env.LB_TRUST_HEADER_COMMANDS;
  });

  it("runs the command and uses its trimmed stdout as the value", async () => {
    const merged = await resolveHeaders({ file: { "X-Token": { command: `node -e "console.log('  tok-123  ')"` } } });
    expect(merged).toEqual({ "X-Token": "tok-123" });
  });

  it("runs the command once per process, even across resolves", async () => {
    const marker = join(dir, "runs.log");
    const file = { "X-Once": { command: `node -e "require('fs').appendFileSync('${marker}', 'x')"; echo once` } };
    await resolveHeaders({ file });
    await resolveHeaders({ file });
    expect(readFileSync(marker, "utf8")).toBe("x");
  });

  it("never runs a command that a flag overrides", async () => {
    const merged = await resolveHeaders({
      flags: ["X-Token: from-flag"],
      file: { "x-token": { command: `node -e "process.exit(1)" # overridden` } },
    });
    expect(merged).toEqual({ "X-Token": "from-flag" });
  });

  it("never runs a command behind a reserved name", async () => {
    const merged = await resolveHeaders({ file: { Authorization: { command: `node -e "process.exit(1)" # reserved` } } });
    expect(merged).toEqual({});
  });

  it("surfaces a failing command with its stderr", async () => {
    const file = { "X-Fail": { command: `node -e "console.error('boom'); process.exit(2)"` } };
    await expect(resolveHeaders({ file })).rejects.toThrow(HeaderError);
    await expect(resolveHeaders({ file })).rejects.toThrow(/X-Fail.*boom/s);
  });

  it("rejects a command that produces no output", async () => {
    const file = { "X-Empty": { command: `node -e "process.exit(0)"` } };
    await expect(resolveHeaders({ file })).rejects.toThrow(/produced no output/);
  });

  it("rejects a command that produces multiple lines", async () => {
    const file = { "X-Multi": { command: `node -e "console.log('a'); console.log('b')"` } };
    await expect(resolveHeaders({ file })).rejects.toThrow(/single line/);
  });

  it("rejects a config object that is not { command }", async () => {
    await expect(resolveHeaders({ file: { "X-Bad": {} as never } })).rejects.toThrow(/expected a string or/);
  });

  it("refuses an untrusted command when not interactive", async () => {
    delete process.env.LB_TRUST_HEADER_COMMANDS;
    const original = process.stdin.isTTY;
    process.stdin.isTTY = false;
    try {
      const file = { "X-Untrusted": { command: `node -e "console.log('nope')" # untrusted` } };
      await expect(resolveHeaders({ file })).rejects.toThrow(/not trusted/);
    } finally {
      process.stdin.isTTY = original;
    }
  });

  it("runs a previously approved command without prompting", async () => {
    delete process.env.LB_TRUST_HEADER_COMMANDS;
    const command = `node -e "console.log('trusted-tok')"`;
    const hash = createHash("sha256").update(command).digest("hex");
    writeFileSync(process.env.LB_TRUSTED_FILE!, JSON.stringify({ [hash]: command }));
    const merged = await resolveHeaders({ file: { "X-Trusted": { command } } });
    expect(merged).toEqual({ "X-Trusted": "trusted-tok" });
  });
});

describe("redactHeaders", () => {
  it("shows names but never values", () => {
    const output = redactHeaders({ "CF-Access-Client-Secret": "s3cr3t", "X-Foo": "bar" });
    expect(output).toContain("CF-Access-Client-Secret: <redacted>");
    expect(output).not.toContain("s3cr3t");
    expect(output).not.toContain("bar");
  });
});
