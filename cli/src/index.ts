#!/usr/bin/env node
import { createRequire } from "node:module";
import { Command } from "commander";
import { DEFAULT_INSTRUCTIONS_FILE, renderInstructions, writeInstructions } from "./commands/ai-instructions.js";
import { generate } from "./commands/generate.js";
import { login } from "./commands/login.js";
import { logout } from "./commands/logout.js";
import { pull } from "./commands/pull.js";
import { push } from "./commands/push.js";
import { review } from "./commands/review.js";
import { sync } from "./commands/sync.js";
import { validate } from "./commands/validate.js";
import { whoami } from "./commands/whoami.js";
import { type CliOptions, ConfigError, resolveConfigs, resolveServer } from "./lib/config.js";

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

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

// Resolve every configured project and run the command for each. Config errors
// abort up front; a per-project failure is reported and the rest continue.
async function run(fn: (config: Awaited<ReturnType<typeof resolveConfigs>>[number]) => Promise<void>, options: CliOptions) {
  let configs: Awaited<ReturnType<typeof resolveConfigs>>;
  try {
    configs = await resolveConfigs(options);
  } catch (error) {
    process.exitCode = error instanceof ConfigError ? 2 : 1;
    console.error(`lb: ${message(error)}`);
    return;
  }

  for (const config of configs) {
    try {
      await fn(config);
    } catch (error) {
      process.exitCode = 1;
      console.error(`lb: ${config.project}: ${message(error)}`);
    }
  }
}

// For commands that need only the server URL (+ maybe a stored token), not a project.
async function runServer(fn: (server: Awaited<ReturnType<typeof resolveServer>>) => Promise<void>, options: CliOptions) {
  try {
    await fn(await resolveServer(options));
  } catch (error) {
    process.exitCode = 1;
    console.error(`lb: ${error instanceof Error ? error.message : String(error)}`);
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
      console.error(`${config.project}: pushed ${result.written} draft(s) for locale ${result.locale}${scope} — review with \`lb review\``);
    }, options),
  );

withCommonOptions(program.command("review"))
  .description("Open the review page (editor filtered to this push session) in your browser")
  .option("-s, --session <id>", "session to review (or env LB_SESSION; default: git branch)")
  .action((options: CliOptions) =>
    run(async (config) => {
      const url = await review(config);
      console.error(`${config.project}: opening ${url}`);
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

withCommonOptions(program.command("validate"))
  .alias("valid")
  .description("Check the config is valid and every project exists and is reachable")
  .action(async (options: CliOptions) => {
    try {
      const results = await validate(await resolveConfigs(options));
      for (const result of results) {
        if (result.ok) {
          console.error(`✓ ${result.project}`);
        } else {
          process.exitCode = 1;
          console.error(`✗ ${result.project}\n    ${result.problems.join("\n    ")}`);
        }
      }
    } catch (error) {
      process.exitCode = error instanceof ConfigError ? 2 : 1;
      console.error(`lb: ${message(error)}`);
    }
  });

withCommonOptions(program.command("login"))
  .description("Authorize this machine in your browser and store a token")
  .option("--name <name>", "token/device name shown on the platform (default: hostname)")
  .action((options: CliOptions) =>
    runServer(async (server) => {
      const result = await login(server, options.name);
      console.error(`Logged in${result.user ? ` as ${result.user}` : ""}. Token stored for ${result.url}.`);
    }, options),
  );

withCommonOptions(program.command("logout"))
  .description("Remove the stored token for this server")
  .action((options: CliOptions) =>
    runServer(async (server) => {
      const removed = await logout(server);
      console.error(removed ? `Logged out of ${server.url}.` : `No stored token for ${server.url}.`);
    }, options),
  );

withCommonOptions(program.command("whoami"))
  .description("Show the user and projects the current token can reach")
  .action((options: CliOptions) =>
    runServer(async (server) => {
      const { user, projects } = await whoami(server);
      console.error(`${user.name ? `${user.name} <${user.email}>` : user.email} — ${projects.length} project(s): ${projects.join(", ")}`);
    }, options),
  );

program.parseAsync();
