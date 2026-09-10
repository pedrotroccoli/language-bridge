import { describe, expect, it } from "vitest";
import { chunkEntries, flattenNamespaces, nestEntries } from "../src/lib/tree.js";
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
});

describe("chunkEntries", () => {
  it("slices entries preserving order and covering every entry", () => {
    const entries: Entry[] = Array.from({ length: 5 }, (_, index) => ["ns", `k${index}`, "v"]);
    const chunks = chunkEntries(entries, 2);
    expect(chunks.map((chunk) => chunk.length)).toEqual([2, 2, 1]);
    expect(chunks.flat()).toEqual(entries);
  });
});
