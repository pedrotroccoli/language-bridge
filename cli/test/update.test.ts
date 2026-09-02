import { describe, expect, it } from "vitest";
import { isNewer } from "../src/lib/update.js";

describe("isNewer", () => {
  it("compares segments numerically, not lexically", () => {
    expect(isNewer("1.2.10", "1.2.9")).toBe(true);
    expect(isNewer("1.10.0", "1.9.0")).toBe(true);
  });

  it("is false for equal or older versions", () => {
    expect(isNewer("1.2.3", "1.2.3")).toBe(false);
    expect(isNewer("1.2.3", "2.0.0")).toBe(false);
  });

  it("treats missing segments as zero", () => {
    expect(isNewer("1.2.1", "1.2")).toBe(true);
    expect(isNewer("1.2", "1.2.0")).toBe(false);
  });
});
