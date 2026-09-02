#!/usr/bin/env node
import { createRequire } from "node:module";
import { Command } from "commander";
import { DEFAULT_INSTRUCTIONS_FILE, renderInstructions, writeInstructions } from "./commands/ai-instructions.js";
import { generate } from "./commands/generate.js";
import { init } from "./commands/init.js";
import { login } from "./commands/login.js";
import { logout } from "./commands/logout.js";
import { pull } from "./commands/pull.js";
import { push } from "./commands/push.js";
import { review } from "./commands/review.js";
import { sync } from "./commands/sync.js";
import { validateConfig } from "./commands/validate-config.js";
import { whoami } from "./commands/whoami.js";
import { check } from "./commands/check.js";
import { type CompletionCommand, SHELLS, type Shell, completionScript } from "./commands/completion.js";
import { BANNER } from "./lib/banner.js";
import { type CliOptions, ConfigError, resolveConfigs, resolveServer } from "./lib/config.js";
import { enableDebug } from "./lib/debug.js";
import { maybeNotifyUpdate } from "./lib/update.js";

const require = createRequire(import.meta.url);
const pkg = require("../package.json") as { name: string; version: string };

// Repeatable --namespace collects into an array.
function collect(value: string, previous: string[] = []): string[] {
  return [...previous, value];
}

const program = new Command();

program
  .name("lb")
  .description("Language Bridge — pull translations and generate typed i18next resources.")
  .version(pkg.version)
  .addHelpText("beforeAll", BANNER);

// Options shared by every command, applied per-command so they show in --help.
function withCommonOptions(command: Command): Command {
  return command
    .option("-t, --token <token>", "API bearer token (or env LB_TOKEN)")
    .option("-u, --url <url>", "server base URL (or env LB_URL)")
    .option("-p, --project <slug>", "project slug (or env LB_PROJECT)")
    .option("-l, --locale <code>", "locale to pull (defaults to the project's source locale)")
    .option("-n, --namespace <name>", "namespace to include (repeatable; default: all)", collect)
    .option("--include-drafts", "include unpublished values")
    .option("--json-dir <dir>", "directory for raw JSON (pull/generate)")
    .option("--verbose", "log requests and responses (also LB_DEBUG=1 or DEBUG=lb)");
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

// Resolve every configured project and run the command for each. Config errors
// abort up front; a per-project failure is reported and the rest continue.
async function run(fn: (config: Awaited<ReturnType<typeof resolveConfigs>>[number]) => Promise<void>, options: CliOptions) {
  if (options.verbose) enableDebug();
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
  if (options.verbose) enableDebug();
  try {
    await fn(await resolveServer(options));
  } catch (error) {
    process.exitCode = 1;
    console.error(`lb: ${error instanceof Error ? error.message : String(error)}`);
  }
}

program
  .command("init")
  .description("Scaffold a language-bridge.json config in the current directory")
  .option("-u, --url <url>", "server base URL (or env LB_URL)")
  .option("-t, --token <token>", "API bearer token (or env LB_TOKEN)")
  .option("-f, --force", "overwrite an existing config")
  .action((options: CliOptions & { force?: boolean }) =>
    runServer(async (server) => {
      console.error(BANNER);
      const result = await init(server, options.force);
      if (!result.created) {
        console.error(`${result.path} already exists — re-run with --force to overwrite.`);
        return;
      }
      const projects = result.projects.length > 0
        ? `prefilled with your project(s): ${result.projects.join(", ")}`
        : "edit the project slug, then run `lb login`";
      console.error(`Created ${result.path} — ${projects}.\nNext: \`lb validate-config\` to check it, \`lb sync\` to generate types.`);
    }, options),
  );

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
      for (const path of result.preview_paths ?? []) {
        console.error(`  session preview: ${path}`);
      }
      for (const path of result.playground_paths ?? []) {
        console.error(`  playground: ${path}`);
      }
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

withCommonOptions(program.command("validate-config"))
  .aliases(["validate", "valid"])
  .description("Validate the local config: token works, projects exist, locales/namespaces are real")
  .option("--json", "print results as JSON on stdout")
  .action(async (options: CliOptions) => {
    if (options.verbose) enableDebug();
    try {
      const results = await validateConfig(await resolveConfigs(options));
      if (results.some((result) => !result.ok)) process.exitCode = 1;
      if (options.json) {
        process.stdout.write(`${JSON.stringify(results, null, 2)}\n`);
        return;
      }
      for (const result of results) {
        if (result.ok) {
          console.error(`✓ ${result.project}`);
        } else {
          console.error(`✗ ${result.project}\n    ${result.problems.join("\n    ")}`);
        }
      }
    } catch (error) {
      process.exitCode = error instanceof ConfigError ? 2 : 1;
      console.error(`lb: ${message(error)}`);
    }
  });

withCommonOptions(program.command("check"))
  .description("Fail (exit 1) when keys exist only in the playground — a CI guard against shipping unpublished keys")
  .option("--json", "print results as JSON on stdout")
  .action((options: CliOptions) =>
    run(async (config) => {
      const result = await check(config);
      if (options.json) {
        process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
        if (!result.ok) process.exitCode = 1;
        return;
      }
      if (result.ok) {
        console.error(`✓ ${config.project}: every key is published`);
        return;
      }
      process.exitCode = 1;
      console.error(`✗ ${config.project}: ${result.unpublished.length} key(s) exist only in the playground:`);
      for (const key of result.unpublished) console.error(`    ${key}`);
      console.error(`  Publish them (\`lb review\`, then approve in the editor) before deploying.`);
    }, options),
  );

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
  .option("--json", "print the result as JSON on stdout")
  .action((options: CliOptions) =>
    runServer(async (server) => {
      const result = await whoami(server);
      if (options.json) {
        process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
        return;
      }
      const { user, projects } = result;
      console.error(`${user.name ? `${user.name} <${user.email}>` : user.email} — ${projects.length} project(s): ${projects.join(", ")}`);
    }, options),
  );

program
  .command("completion")
  .description("Print a shell completion script (bash or zsh)")
  .argument("<shell>", `one of: ${SHELLS.join(", ")}`)
  .action((shell: string) => {
    if (!SHELLS.includes(shell as Shell)) {
      process.exitCode = 2;
      console.error(`lb: unsupported shell "${shell}" — use ${SHELLS.join(" or ")}.`);
      return;
    }
    const commands: CompletionCommand[] = program.commands
      .filter((command) => command.name() !== "completion")
      .map((command) => ({ name: command.name(), description: command.description() }));
    process.stdout.write(completionScript(shell as Shell, commands));
  });

await program.parseAsync();
await maybeNotifyUpdate(pkg.name, pkg.version);
