import { validSet } from "./skills_sets.mjs";

export const FEATURES = ["rules", "git-hooks", "claude-hooks", "post-git-hook", "agents-doc", "skills", "ci", "ai-risk",
  "pr-template", "approval-gate", "privacy", "research-ref"];
const MINIMAL = ["rules", "git-hooks"];
const STANDARD = [...MINIMAL, "claude-hooks", "post-git-hook", "agents-doc", "skills"];
const PROFILES = { minimal: MINIMAL, standard: STANDARD, factory: [...STANDARD, "ci", "ai-risk", "pr-template"], local: STANDARD };
const HOOKS_VIA = ["auto", "githooks", "husky", "lefthook", "precommit", "none"];

export const USAGE = `Usage: bootstrap.sh <target> [--plan | --apply] [--profile minimal|standard|factory|local] [--local] [--upgrade]
                    [--with a,b] [--without a,b] [--hooks-via auto|githooks|husky|lefthook|precommit|none]
                    [--skills-from PATH] [--skills SET] [--force] [--yes] [-h|--help]

Repo-aware bootstrap of the AI guardrails (rules, clean-code scripts, git and Claude Code hooks).
Prints the plan as JSON on stdout and a digest on stderr. --plan (default) writes nothing; --apply executes it.

Profiles:
  minimal   rules, clean-code scripts, git pre-commit and pre-push hooks
  standard  minimal + Claude Code hooks (PreToolUse git guard, PostToolUse git check, PostToolUse analyzer and
            docs lint, Stop analyzer) + AGENTS.md guardrails section + core skill symlinks (default)
  factory   standard + ci + ai-risk + pr-template (no approval-gate: factories run unattended)
  local     standard guardrails without changing tracked files (alias --local): hooks in .claude/settings.local.json,
            git hooks in .git/hooks, a note in .git/info/local-guardrails.md instead of AGENTS.md, every installed
            path in .git/info/exclude, install record in .git/info/local-guardrails.json; --with ci is refused
Skills (--skills): core (write-plan, align, implement, review, watch, plan-implement-review-watch, plus the support skills they call: plan-implement-review, verify-change, monitor, review-*; default),
  core+aliases (adds the one-line aliases, apirw, apirwm and code-review), all, none, or a comma list of names. The source is --skills-from PATH or
  $PUBLIC_AI_DIR; with neither, the skills step is a manual step.
Drift: .claude/ai-guardrails.json (local: .git/info/local-guardrails.json) records the source commit and a hash per
  installed file; --upgrade re-applies only files changed upstream and keeps locally modified ones unless --force.
Features for --with and --without: rules, git-hooks, claude-hooks, post-git-hook, agents-doc, skills, ci, ai-risk,
  pr-template, approval-gate, privacy, research-ref.
Plan step: {id, action: create|merge|skip|manual, path, reason}. Idempotent: a second --apply changes nothing.
Existing differing files are kept unless --force. --apply on a dirty working tree needs --yes.
Exit: 0 ok, 1 a step failed, 2 usage, 3 precondition (not a git repo, dirty tree without --yes)`;

export class UsageError extends Error {}

export class HelpRequested extends Error {}

const csv = (value) => value.split(",").filter(Boolean);

const VALUE_OPTIONS = {
  "--profile": (opts, value) => {
    if (!Object.keys(PROFILES).includes(value)) throw new UsageError("argument --profile: invalid choice: '" + value + "'");
    opts.profile = value;
  },
  "--with": (opts, value) => opts.with.push(...csv(value)),
  "--without": (opts, value) => opts.without.push(...csv(value)),
  "--hooks-via": (opts, value) => {
    if (!HOOKS_VIA.includes(value)) throw new UsageError("argument --hooks-via: invalid choice: '" + value + "'");
    opts.hooksVia = value;
  },
  "--skills-from": (opts, value) => {
    opts.skillsFrom = value;
  },
  "--skills": (opts, value) => {
    if (!validSet(value)) throw new UsageError("argument --skills: use core, core+aliases, all, none or a comma list of skill names");
    opts.skills = value;
  },
};
const FLAG_OPTIONS = { "--local": "local", "--upgrade": "upgrade", "--force": "force", "--yes": "yes" };

class ArgvReader {
  constructor(argv) {
    this.argv = argv;
    this.index = 0;
    this.opts = { target: null, mode: null, profile: null, local: false, upgrade: false, with: [], without: [],
      hooksVia: "auto", skillsFrom: null, skills: "core", force: false, yes: false };
  }

  readOption() {
    const arg = this.argv[this.index];
    const eq = arg.startsWith("--") ? arg.indexOf("=") : -1;
    const name = eq > 0 ? arg.slice(0, eq) : arg;
    if (name in VALUE_OPTIONS) {
      const value = eq > 0 ? arg.slice(eq + 1) : this.argv[++this.index];
      if (value === undefined) throw new UsageError("argument " + name + ": expected one argument");
      VALUE_OPTIONS[name](this.opts, value);
    } else if (name in FLAG_OPTIONS) this.opts[FLAG_OPTIONS[name]] = true;
    else if (name === "--plan" || name === "--apply") this.setMode(name);
    else if (name === "-h" || name === "--help") throw new HelpRequested();
    else throw new UsageError("unrecognized arguments: " + arg);
  }

  setMode(name) {
    const mode = name.slice(2);
    if (this.opts.mode && this.opts.mode !== mode) throw new UsageError("argument " + name + ": not allowed with argument --" + this.opts.mode);
    this.opts.mode = mode;
  }

  read() {
    for (; this.index < this.argv.length; this.index++) {
      const arg = this.argv[this.index];
      if (arg.startsWith("-") && arg !== "-") this.readOption();
      else if (this.opts.target === null) this.opts.target = arg;
      else throw new UsageError("unrecognized arguments: " + arg);
    }
    if (this.opts.target === null) throw new UsageError("the following arguments are required: target");
    return this.opts;
  }
}

function resolveFeatures(profile, withList, without) {
  const unknown = [...withList, ...without].filter((name) => !FEATURES.includes(name));
  if (unknown.length) throw new UsageError("unknown feature: " + unknown.join(", "));
  const chosen = new Set([...PROFILES[profile], ...withList]);
  for (const name of without) chosen.delete(name);
  return FEATURES.filter((name) => chosen.has(name));
}

function resolveProfile(options) {
  if (options.local && ![null, "local"].includes(options.profile)) throw new UsageError("--local conflicts with --profile " + options.profile);
  const profile = options.local ? "local" : (options.profile || "standard");
  if (profile === "local" && options.with.includes("ci")) throw new UsageError("ci edits tracked files: not available with the local profile");
  return profile;
}

export function parse(argv) {
  const options = new ArgvReader(argv).read();
  options.profile = resolveProfile(options);
  options.mode = options.mode === "apply" ? "apply" : "plan";
  options.apply = options.mode === "apply";
  options.features = resolveFeatures(options.profile, options.with, options.without);
  if (options.skills === "none") options.features = options.features.filter((name) => name !== "skills");
  return options;
}
