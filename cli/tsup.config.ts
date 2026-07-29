import { defineConfig } from "tsup";

export default defineConfig({
  // `index` is the CLI bin (keeps its shebang); `runtime` is the tiny library
  // consumers import as `@language-bridge/cli/runtime`.
  entry: ["src/index.ts", "src/runtime.ts"],
  format: ["esm"],
  target: "node22",
  dts: true,
  clean: true,
  sourcemap: false,
});
