#!/usr/bin/env node
import { createRequire } from "node:module";
import { Command } from "commander";
import { DEFAULT_INSTRUCTIONS_FILE, renderInstructions, writeInstructions } from "./commands/ai-instructions.js";
import { generate } from "./commands/generate.js";
import { pull } from "./commands/pull.js";
import { push } from "./commands/push.js";
import { sync } from "./commands/sync.js";
import { type CliOptions, ConfigError, resolveConfig } from "./lib/config.js";

const require = createRequire(import.meta.url);
const pkg = require("../package.json") as { version: string };

// Repeatable --namespace collects into an array.
function collect(value: string, previous: string[] = []): string[] {
  return [...previous, value];
}

const program = new Command();

program
  .name("lb")
  .description("Language Bridge — pull translations and generate typed i18next resources.")
  .version(pkg.version);

// Options shared by every command, applied per-command so they show in --help.
function withCommonOptions(command: Command): Command {
  return command
    .option("-t, --token <token>", "API bearer token (or env LB_TOKEN)")
    .option("-u, --url <url>", "server base URL (or env LB_URL)")
    .option("-p, --project <slug>", "project slug (or env LB_PROJECT)")
    .option("-l, --locale <code>", "locale to pull (defaults to the project's source locale)")
    .option("-n, --namespace <name>", "namespace to include (repeatable; default: all)", collect)
    .option("--include-drafts", "include unpublished values")
    .option("--json-dir <dir>", "directory for raw JSON (pull/generate)");
}

async function run(fn: (config: Awaited<ReturnType<typeof resolveConfig>>) => Promise<void>, options: CliOptions) {
  try {
    const config = await resolveConfig(options);
    await fn(config);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.exitCode = error instanceof ConfigError ? 2 : 1;
    console.error(`lb: ${message}`);
  }
}

withCommonOptions(program.command("pull"))
  .description("Fetch translations and write raw JSON to --json-dir")
  .action((options: CliOptions) =>
    run(async (config) => {
      const { namespaces } = await pull(config, true);
      console.error(`Pulled ${Object.keys(namespaces).length} namespace(s) to ${config.jsonDir}`);
    }, options),
  );

withCommonOptions(program.command("generate"))
  .alias("types")
  .description("Generate the .d.ts from previously pulled JSON")
  .option("-o, --out <path>", "output .d.ts path")
  .option("--no-params", "skip interpolation-param types (keys only)")
  .action((options: CliOptions) =>
    run(async (config) => {
      await generate(config);
      console.error(`Wrote ${config.out}`);
    }, options),
  );

withCommonOptions(program.command("sync", { isDefault: true }))
  .description("Pull + generate types in one step (default command)")
  .option("-o, --out <path>", "output .d.ts path")
  .option("--no-params", "skip interpolation-param types (keys only)")
  .option("--keep-json", "also write the raw JSON to --json-dir")
  .action((options: CliOptions) =>
    run(async (config) => {
      const result = await sync(config);
      console.error(
        `Wrote ${result.out} (${result.namespaces.length} namespace(s), locale ${result.locale})`,
      );
    }, options),
  );

withCommonOptions(program.command("push"))
  .description("Push local source-locale JSON as proposals for human review")
  .option("-s, --session <id>", "grouping label for the push (or env LB_SESSION; default: git branch)")
  .action((options: CliOptions) =>
    run(async (config) => {
      const result = await push(config);
      const scope = result.session ? ` (session ${result.session})` : "";
      console.error(`Pushed ${result.proposed} proposal(s) for locale ${result.locale}${scope}`);
    }, options),
  );

withCommonOptions(program.command("ai-instructions"))
  .description("Print AI agent rules for this project (or write them to a file)")
  .option("-w, --write [file]", `write to a file (default ${DEFAULT_INSTRUCTIONS_FILE}), wrapping in lb markers`)
  .action((options: CliOptions) =>
    run(async (config) => {
      const block = await renderInstructions(config);
      if (options.write === undefined) {
        process.stdout.write(`${block}\n`);
        return;
      }
      const file = typeof options.write === "string" ? options.write : DEFAULT_INSTRUCTIONS_FILE;
      await writeInstructions(file, block);
      console.error(`Wrote AI instructions to ${file}`);
    }, options),
  );

program.parseAsync();
