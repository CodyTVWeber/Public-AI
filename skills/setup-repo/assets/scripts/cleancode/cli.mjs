import { parseArgs, UsageError } from "./args.mjs";
import { describeRules } from "./catalog.mjs";
import { fileTargets } from "./filetargets.mjs";
import { GitError } from "./gitdiff.mjs";
import { HELP, USAGE } from "./help.mjs";
import * as hooks from "./hooks.mjs";
import { exitCode, headline, renderHuman, skippedJson, toJson } from "./report.mjs";
import { analyzeAll } from "./runner.mjs";
import { loadConfig, skipReason } from "./settings.mjs";
import { changedTargets, fileOptions, rangeTargets, stagedTargets } from "./targets.mjs";

const USAGE_ERROR = 2;
const PRECONDITION_ERROR = 3;

function collect(args) {
  if (args.staged) return stagedTargets(process.cwd());
  if (args.changed !== undefined) return changedTargets(process.cwd(), args.changed);
  if (args.range) return rangeTargets(process.cwd(), args.range);
  return fileTargets(args.files, fileOptions({ allLines: args.all_lines }));
}

function reportRun(targets, config) {
  const findings = analyzeAll(targets, config);
  process.stdout.write(toJson(findings, targets.length) + "\n");
  if (findings.length) process.stderr.write(`${headline(findings)}\n${renderHuman(findings)}\n`);
  return exitCode(findings);
}

function runHook(args, config) {
  const payload = hooks.readPayload();
  const session = new hooks.HookSession(config, process.stdout, process.stderr);
  return args.hook ? session.postToolUse(payload) : session.stop(payload);
}

function skipRun(args, reason) {
  process.stderr.write(`clean-code: skipped (${reason}=1)\n`);
  if (!(args.hook || args.stop_hook)) process.stdout.write(skippedJson() + "\n");
  return 0;
}

function runChecked(args, config) {
  try {
    return reportRun(collect(args), config);
  } catch (error) {
    if (!(error instanceof GitError)) throw error;
    process.stderr.write(`clean-code: ${error.message}\n`);
    return PRECONDITION_ERROR;
  }
}

function hasMode(args) {
  return Boolean(args.files.length || args.staged || args.range || args.changed !== undefined);
}

function parseOrFail(argv) {
  try {
    return parseArgs(argv);
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    process.stderr.write(`${USAGE}code-quality-check.sh: error: ${error.message}\n`);
    return null;
  }
}

export function main(argv, env = process.env) {
  const args = parseOrFail(argv);
  if (args === null) return USAGE_ERROR;
  if (args.help) {
    process.stdout.write(HELP);
    return 0;
  }
  const reason = skipReason(env);
  if (reason) return skipRun(args, reason);
  if (args.list_rules) {
    process.stdout.write(JSON.stringify(describeRules(), null, 2) + "\n");
    return 0;
  }
  const config = loadConfig(env);
  if (args.hook || args.stop_hook) return runHook(args, config);
  if (!hasMode(args)) {
    process.stderr.write("clean-code: give FILE..., --staged or --changed (see -h)\n");
    return USAGE_ERROR;
  }
  return runChecked(args, config);
}
