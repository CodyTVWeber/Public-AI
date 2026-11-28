import fs from "node:fs";
import path from "node:path";
import { ciFilePath } from "./steps_ci.mjs";
import { templatePath } from "./steps_files.mjs";

export const MARKER_BEGIN = "<!-- ai-guardrails:begin -->";
export const MARKER_END = "<!-- ai-guardrails:end -->";
export const NO_PIPELINE = "No pipeline jobs installed: local and Claude hooks are the guardrails.";
const ALWAYS_INSTALLED = ["scripts"];
const PUBLIC_AI_VAR = '"$PUBLIC_AI_DIR"/skills/setup-repo/scripts/';
const INSTALLED_LINES = {
  rules: "Rules: `.claude/rules/` holds clean-code, ban-comments, ban-worktrees, small-mrs, docs-current-or-dated and research-latest-main.",
  scripts: "Analyzer, size gate and git-command scanner: `scripts/clean-code/`.",
  "git-hooks": "Git hooks: pre-commit runs `check-clean-code.sh` (analyzer on staged lines), pre-push runs `pre-push-gate.sh` (branch size). Wired via {via}.",
  "claude-hooks": "Claude Code hooks in `{settings}`: PreToolUse(Bash) guard on push and MR create (size and clean code), PostToolUse docs lint and analyzer after edits, Stop analyzer.",
  "post-git-hook": "PostToolUse(Bash) `post-git-check.sh`: analyzer on each commit's lines, subject length, branch size, one-PR reminder after push, conflict files after merge or pull.",
  "ai-risk": "AI risk: `docs/rules/` holds risk tiers, merge policy (`conservative`, auto-merge off) and agent-stop rules; `scripts/ai-risk/` classifies a change.",
  "pr-template": "PR template: `{template}`; `scripts/clean-code/check-pr-body.sh` validates a body against it.",
  "approval-gate": "Approval gate: `scripts/guard/git-approval-guard.sh` (PreToolUse on Bash).",
  privacy: "Privacy gate: `scripts/check-privacy.sh`; local patterns live in `<git-dir>/info/privacy-patterns` (`--strict` or `PRIVACY_REQUIRE_PATTERNS=1` blocks when missing).",
  "research-ref": "Research ref: `scripts/guard/research-ref.sh` (SessionStart) reports when the checkout is behind the default branch.",
  ci: "CI: `{ci}` runs the same `scripts/clean-code/*` checks on every merge request.",
};
const STACK_NOTES = {
  node: "JS/TS: merge `assets/lint/eslint.clean-code.js` from the setup-repo skill into the flat ESLint config (max-params, max-depth, function size); relax it for tests and generated code.",
  typescript: "TypeScript: keep `strict` on; the analyzer covers params, nesting and function length on changed lines.",
  maven: "Maven: merge `assets/lint/detekt-clean-code.yml` into the detekt config for Kotlin; Java relies on the analyzer plus checkstyle.",
  gradle: "Gradle: merge `assets/lint/detekt-clean-code.yml` into the detekt config for Kotlin; Java relies on the analyzer plus checkstyle.",
  python: "Python: merge `assets/lint/ruff-clean-code.toml` into `pyproject.toml`.",
  go: "Go: enable `funlen`, `gocyclo` and `nestif` in golangci-lint at warn first.",
  rust: "Rust: enable clippy `too_many_arguments` and `cognitive_complexity`.",
  ruby: "Ruby: set RuboCop `Metrics/MethodLength`, `Metrics/ParameterLists` and `Metrics/BlockNesting`.",
  shell: "Shell: the analyzer covers function length, parameters and nesting; run shellcheck in the repo's own checks.",
};
const FALLBACK_NOTE = "No known stack: pick a linter that can cap nesting depth, parameter count and function length.";

function fill(text, values) {
  return text.replace(/\{(\w+)\}/g, (whole, key) => (key in values ? values[key] : whole));
}

function installedBlock(ctx) {
  const template = templatePath(ctx.detected.git.forge) || "the forge's PR template";
  const values = { via: ctx.hooksVia, template, ci: ciFilePath(ctx) || "pipeline", settings: ctx.settingsRel };
  const lines = Object.entries(INSTALLED_LINES)
    .filter(([name]) => ALWAYS_INSTALLED.includes(name) || ctx.on(name)).map(([, text]) => fill(text, values));
  return lines.map((line) => "- " + line).join("\n");
}

function skillsBlock(ctx) {
  if (!ctx.on("skills")) return "No skills linked.";
  return "Skills are symlinks `.claude/skills/<name>` (local, one `.git/info/exclude` entry per link) into a Public-AI clone at "
    + "`$PUBLIC_AI_DIR`; set `" + ctx.options.skills + "`. Relink: `" + PUBLIC_AI_VAR + "link-skills.sh . --skills "
    + ctx.options.skills + "`.";
}

function stackBlock(ctx) {
  const lines = ctx.detected.stacks.map((stack) => STACK_NOTES[stack.name]).filter(Boolean);
  return lines.map((line) => "- " + line).join("\n") || FALLBACK_NOTE;
}

function pipelineBlock(ctx) {
  const file = ciFilePath(ctx);
  if (!ctx.on("ci") || !file) return NO_PIPELINE;
  return "`" + file + "` runs the same `scripts/clean-code/*` checks on every merge request. CI is the control a PR cannot "
    + "silently delete: keep these jobs required.";
}

function flagsLine(ctx) {
  const options = ctx.options;
  const parts = ["--profile " + options.profile];
  if (options.with.length) parts.push("--with " + options.with.join(","));
  if (options.without.length) parts.push("--without " + options.without.join(","));
  if (options.hooksVia !== "auto") parts.push("--hooks-via " + options.hooksVia);
  if (options.skills !== "core") parts.push("--skills " + options.skills);
  return parts.join(" ");
}

function rerunBlock(ctx) {
  const bootstrap = PUBLIC_AI_VAR + "bootstrap.sh . " + flagsLine(ctx);
  return "`" + bootstrap + " --plan`, then `--apply`. Check with `" + PUBLIC_AI_VAR + "verify-repo.sh .`. "
    + "`--upgrade` re-applies files changed upstream and keeps locally modified ones. Differing files are kept unless `--force`.";
}

function approvalBlock(ctx) {
  if (!ctx.on("approval-gate")) return "";
  return fs.readFileSync(path.join(ctx.assets, "AGENTS.approval.md"), "utf8");
}

export function renderSection(ctx) {
  let text = fs.readFileSync(path.join(ctx.assets, "AGENTS.guardrails.md"), "utf8");
  const values = { INSTALLED: installedBlock(ctx), SKILLS: skillsBlock(ctx), STACK_NOTES: stackBlock(ctx),
    PIPELINE: pipelineBlock(ctx), APPROVAL: approvalBlock(ctx), RERUN: rerunBlock(ctx) };
  for (const [key, value] of Object.entries(values)) text = text.split("{{" + key + "}}").join(value);
  return text;
}
