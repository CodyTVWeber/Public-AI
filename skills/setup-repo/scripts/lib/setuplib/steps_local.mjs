import path from "node:path";
import { blockNeeded, writeBlock } from "./exclude.mjs";
import { Step, writeBytes } from "./plan_model.mjs";
import { gitPath, LOCAL_NOTE_RELATIVE } from "./record.mjs";
import { readText } from "./util.mjs";

const EXCLUDE_TAG = "local";
const SETTINGS_ENTRY = ".claude/settings.local.json";
const SCRIPTS_DIR = "scripts/clean-code/";
const SETTINGS_FEATURES = ["claude-hooks", "post-git-hook", "approval-gate", "research-ref"];
const NOTE_HEADER = "<!-- Local guardrails note: written to the git dir, not to AGENTS.md, so tracked files stay unchanged. -->\n\n";

function shown(ctx, file) {
  return file.startsWith(ctx.root + path.sep) ? path.relative(ctx.root, file) : file;
}

export function localDocStep(ctx, section) {
  const dest = gitPath(ctx.root, LOCAL_NOTE_RELATIVE);
  const text = NOTE_HEADER + section;
  const current = readText(dest);
  if (current === text) return new Step("agents-doc", "skip", shown(ctx, dest), "local guardrails note is current");
  const action = current === null ? "create" : "merge";
  return new Step("agents-doc", action, shown(ctx, dest), "writes the guardrails note to the git dir; AGENTS.md stays unchanged",
    { run: () => writeBytes(dest, Buffer.from(text), false) });
}

function excludeEntries(ctx) {
  const entries = new Set(SETTINGS_FEATURES.some((name) => ctx.on(name)) ? [SETTINGS_ENTRY] : []);
  for (const file of ctx.installed.keys()) entries.add(file.startsWith(SCRIPTS_DIR) ? SCRIPTS_DIR : file);
  return [...entries].sort();
}

export function excludeStep(ctx) {
  if (!ctx.local) return [];
  const entries = excludeEntries(ctx);
  const file = shown(ctx, path.join(path.dirname(gitPath(ctx.root, LOCAL_NOTE_RELATIVE)), "exclude"));
  if (!blockNeeded(ctx.root, EXCLUDE_TAG, entries)) return [new Step("exclude", "skip", file, "installed paths already excluded")];
  return [new Step("exclude", "merge", file, "excludes " + entries.length + " installed paths so git status stays clean",
    { run: () => writeBlock(ctx.root, EXCLUDE_TAG, entries) })];
}
