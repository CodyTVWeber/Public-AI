import { spawnSync } from "node:child_process";
import { ASSIGN, quoteAll } from "./shellsyntax.mjs";
import {
  COMMIT, COMMIT_LIKE, DENY_HOOKSPATH, DENY_NO_VERIFY as NO_VERIFY, DENY_SKIP, PUSH, PUSH_LIKE, SKIP_SOFT,
} from "./tags.mjs";

export { quoteAll };
export const HOOKS_KEY = "core.hookspath";
const ABBREV_MIN = 6;
const ALIAS_TIMEOUT_MS = 3000;
const GIT_ARG_OPTS = new Set(["-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix",
  "--config-env", "--attr-source"]);
const COMMIT_ARGS = new Set(["-m", "-F", "-c", "-C", "-t", "--message", "--file", "--reuse-message",
  "--reedit-message", "--template", "--author", "--date", "--cleanup", "--fixup", "--squash", "--trailer"]);
const PUSH_ARGS = new Set(["-o", "--push-option", "--repo", "--receive-pack", "--exec"]);
const COMMIT_VALUE_FLAGS = "mFcCt";
const COMMIT_SKIP_FLAGS = "mFcCtSu";
const FALLBACK_WORDS = [["commit", COMMIT], ["push", PUSH], ["merge", COMMIT_LIKE], ["cherry-pick", COMMIT_LIKE],
  ["revert", COMMIT_LIKE], ["send-pack", PUSH_LIKE], ["update-ref", COMMIT_LIKE], ["commit-tree", COMMIT_LIKE]];

export function abbreviation(arg, full, minLen = ABBREV_MIN) {
  return arg.length >= minLen && full.startsWith(arg);
}

export function noteAssign(token, found) {
  const match = ASSIGN.exec(token);
  if (!match) return;
  const [, name, value] = match;
  if (name === "CLEAN_CODE_SKIP" && value !== "" && value !== "0") found.add(DENY_SKIP);
  else if (name === "SKIP" && value) found.add(SKIP_SOFT);
  else if (name === "HUSKY" && value === "0") found.add(SKIP_SOFT);
  else if (name.startsWith("GIT_CONFIG_KEY_") && value.toLowerCase() === HOOKS_KEY) found.add(DENY_HOOKSPATH);
  else if (name === "GIT_CONFIG_PARAMETERS" && value.toLowerCase().includes("hookspath")) found.add(DENY_HOOKSPATH);
}

function scanShortCommitFlags(arg, found) {
  for (let pos = 1; pos < arg.length; pos += 1) {
    const char = arg[pos];
    if (char === "n") {
      found.add(NO_VERIFY);
      return 0;
    }
    if (COMMIT_SKIP_FLAGS.includes(char)) return COMMIT_VALUE_FLAGS.includes(char) && pos === arg.length - 1 ? 1 : 0;
  }
  return 0;
}

export function scanCommit(rest, found) {
  let i = 0;
  while (i < rest.length && rest[i] !== "--") {
    const arg = rest[i];
    if (COMMIT_ARGS.has(arg)) {
      i += 2;
      continue;
    }
    if (arg.startsWith("--") && abbreviation(arg, "--no-verify")) found.add(NO_VERIFY);
    else if (!arg.startsWith("--") && arg.startsWith("-") && arg.length > 1) i += scanShortCommitFlags(arg, found);
    i += 1;
  }
}

function scanLongPushFlag(arg, found) {
  if (abbreviation(arg, "--no-verify")) found.add(NO_VERIFY);
  if (arg.startsWith("--force") || arg === "--delete" || arg === "--mirror") found.add("push-force");
}

export function scanPush(rest, found) {
  let i = 0;
  while (i < rest.length && rest[i] !== "--") {
    const arg = rest[i];
    if (PUSH_ARGS.has(arg)) {
      i += 2;
      continue;
    }
    if (arg.startsWith("--")) scanLongPushFlag(arg, found);
    else if (arg === "-f" || arg === "-d" || arg.startsWith("+") || arg.startsWith(":")) found.add("push-force");
    i += 1;
  }
}

function configEnvEntry(spec) {
  const at = spec.indexOf("=");
  return at < 0 ? spec + "=$" : spec.slice(0, at) + "=$" + spec.slice(at + 1);
}

export function splitGitArgs(args) {
  let i = 0;
  const cfg = [];
  while (i < args.length && args[i].startsWith("-")) {
    if ((args[i] === "-c" || args[i] === "--config-env") && i + 1 < args.length) {
      cfg.push(args[i] === "-c" ? args[i + 1] : configEnvEntry(args[i + 1]));
    } else if (args[i].startsWith("--config-env=")) {
      cfg.push(configEnvEntry(args[i].slice(args[i].indexOf("=") + 1)));
    }
    i += GIT_ARG_OPTS.has(args[i]) ? 2 : 1;
  }
  return [i, cfg];
}

export function hooksOverride(cfg) {
  return cfg.some((entry) => entry.toLowerCase().startsWith(HOOKS_KEY));
}

export function aliasFromConfig(name, cfg) {
  const prefix = "alias." + name.toLowerCase() + "=";
  const entry = cfg.find((item) => item.toLowerCase().startsWith(prefix));
  return entry === undefined ? null : entry.slice(entry.indexOf("=") + 1);
}

export function aliasFromGit(name, cwd) {
  const result = spawnSync("git", ["config", "--get", "alias." + name],
    { cwd: cwd || undefined, encoding: "utf8", timeout: ALIAS_TIMEOUT_MS });
  if (result.error || typeof result.stdout !== "string") return null;
  return result.stdout.trim() || null;
}

export function fallbackTags(text, found) {
  for (const [word, tag] of FALLBACK_WORDS) {
    if (new RegExp("\\bgit\\b[^\\n;&|]*\\b" + word + "\\b").test(text)) found.add(tag);
  }
}

export function coarseTags(text, found) {
  if (!/\bgit\b/i.test(text)) return;
  for (const [word, tag] of FALLBACK_WORDS) {
    if (new RegExp("\\b" + word + "\\b").test(text)) found.add(tag);
  }
}
