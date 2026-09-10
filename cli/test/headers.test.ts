import { describe, expect, it } from "vitest";
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
});

describe("parseHeaderList", () => {
  it("accepts newline- and comma-separated pairs, skipping blanks", () => {
    expect(parseHeaderList("A: 1\nB: 2,C: 3\n\n")).toEqual({ A: "1", B: "2", C: "3" });
  });
});

describe("resolveHeaders", () => {
  it("merges per-key with flag > env > config", () => {
    const merged = resolveHeaders({
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

  it("treats names case-insensitively, keeping the winner's casing", () => {
    const merged = resolveHeaders({ flags: ["X-FOO: flag"], file: { "x-foo": "file" } });
    expect(merged).toEqual({ "X-FOO": "flag" });
  });

  it("returns an empty object when no source is set", () => {
    expect(resolveHeaders({})).toEqual({});
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
