import { describe, expect, it } from "vitest";
import { reviewUrl } from "../src/commands/review.js";
import type { ResolvedConfig } from "../src/lib/config.js";

function config(over: Partial<ResolvedConfig> = {}): ResolvedConfig {
  return {
    token: "lb_pat_x",
    url: "http://server.test",
    project: "main-app",
    out: "o.d.ts",
    jsonDir: ".",
    includeDrafts: false,
    params: true,
    keepJson: false,
    ...over,
  };
}

describe("reviewUrl", () => {
  it("points at the project review page filtered by the session", async () => {
    const url = await reviewUrl(config({ session: "feat/x" }));
    expect(url).toBe("http://server.test/projects/main-app/review?session=feat%2Fx");
  });

  it("omits the session param when there is none", async () => {
    const url = await reviewUrl(config({ session: "" }));
    expect(url).toBe("http://server.test/projects/main-app/review");
  });
});
