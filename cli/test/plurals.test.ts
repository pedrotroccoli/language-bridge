import { describe, expect, it } from "vitest";
import { pluralBase } from "../src/lib/plurals.js";

describe("pluralBase", () => {
  it("collapses i18next plural variants to their base", () => {
    expect(pluralBase("item_one")).toBe("item");
    expect(pluralBase("item_other")).toBe("item");
    expect(pluralBase("day_few")).toBe("day");
  });

  it("returns null for non-plural keys", () => {
    expect(pluralBase("greeting")).toBeNull();
    expect(pluralBase("welcome_message")).toBeNull();
  });

  it("returns null when stripping the suffix leaves no base", () => {
    expect(pluralBase("_one")).toBeNull();
  });
});
