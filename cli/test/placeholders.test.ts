import { describe, expect, it } from "vitest";
import { extractParams } from "../src/lib/placeholders.js";

describe("extractParams", () => {
  it("parses all three placeholder dialects in one string", () => {
    expect(extractParams("Hi {{name}}, {count} left, %{pct}%")).toEqual(["name", "count", "pct"]);
  });

  it("drops i18next formatting after a comma", () => {
    expect(extractParams("You have {{count, number}} items")).toEqual(["count"]);
  });

  it("strips the unescape marker", () => {
    expect(extractParams("{{- rawHtml}}")).toEqual(["rawHtml"]);
  });

  it("ignores i18next nesting references", () => {
    expect(extractParams("$t(common:foo) and {{name}}")).toEqual(["name"]);
  });

  it("de-duplicates repeated variables", () => {
    expect(extractParams("{{n}} + {{n}} = {{sum}}")).toEqual(["n", "sum"]);
  });

  it("returns an empty array when there are no placeholders", () => {
    expect(extractParams("Just plain text")).toEqual([]);
  });
});
