import { describe, expect, it } from "vitest";
import { flattenNamespaces, nestEntries } from "../src/lib/tree.js";
import type { Entry } from "../src/lib/tree.js";

describe("flattenNamespaces / nestEntries", () => {
  it("round-trips nested trees through dotted entries", () => {
    const namespaces = {
      common: { home: { title: "Welcome", nav: { save: "Save" } }, plain: "x" },
      marketing: { cta: "Buy" },
    };
    const entries = flattenNamespaces(namespaces);
    expect(entries).toContainEqual(["common", "home.title", "Welcome"]);
    expect(entries).toContainEqual(["common", "home.nav.save", "Save"]);
    expect(entries).toContainEqual(["marketing", "cta", "Buy"]);
    expect(nestEntries(entries)).toEqual(namespaces);
  });

  it("nests a single dotted entry", () => {
    expect(nestEntries([["common", "a.b.c", "v"]])).toEqual({ common: { a: { b: { c: "v" } } } });
  });

  it("coerces non-string leaves and skips null instead of crashing", () => {
    const tree = { count: 3, enabled: true, missing: null, label: "ok" } as never;
    const entries = flattenNamespaces({ common: tree });
    expect(entries).toContainEqual(["common", "count", "3"]);
    expect(entries).toContainEqual(["common", "enabled", "true"]);
    expect(entries).toContainEqual(["common", "label", "ok"]);
    expect(entries.some(([, key]) => key === "missing")).toBe(false);
  });
});
