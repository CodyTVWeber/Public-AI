import argparse

from .skills_sets import valid_set

FEATURES = ("rules", "git-hooks", "claude-hooks", "post-git-hook", "agents-doc", "skills", "ci", "ai-risk",
            "pr-template", "approval-gate", "privacy", "research-ref")
MINIMAL = ("rules", "git-hooks")
STANDARD = MINIMAL + ("claude-hooks", "post-git-hook", "agents-doc", "skills")
PROFILES = {"minimal": MINIMAL, "standard": STANDARD, "factory": STANDARD + ("ci", "ai-risk", "pr-template"),
            "local": STANDARD}
HOOKS_VIA = ("auto", "githooks", "husky", "lefthook", "precommit", "none")
USAGE_ERROR = 2

DESCRIPTION = """Repo-aware bootstrap of the AI guardrails (rules, clean-code scripts, git and Claude Code hooks).
Prints the plan as JSON on stdout and a digest on stderr. --plan (default) writes nothing; --apply executes it."""
EPILOG = """Profiles:
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
Exit: 0 ok, 1 a step failed, 2 usage, 3 precondition (not a git repo, dirty tree without --yes)"""


class UsageError(Exception):
    pass


def skills_set(value):
    if not valid_set(value):
        raise argparse.ArgumentTypeError("use core, core+aliases, all, none or a comma list of skill names")
    return value


def csv(value):
    return [item for item in value.split(",") if item]


def build_parser():
    parser = argparse.ArgumentParser(prog="bootstrap.sh", description=DESCRIPTION, epilog=EPILOG,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("target")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--plan", action="store_true")
    mode.add_argument("--apply", action="store_true")
    parser.add_argument("--profile", choices=sorted(PROFILES))
    parser.add_argument("--local", action="store_true")
    parser.add_argument("--upgrade", action="store_true")
    parser.add_argument("--with", dest="with_", type=csv, default=[], metavar="a,b")
    parser.add_argument("--without", type=csv, default=[], metavar="a,b")
    parser.add_argument("--hooks-via", choices=HOOKS_VIA, default="auto")
    parser.add_argument("--skills-from", metavar="PATH")
    parser.add_argument("--skills", type=skills_set, default="core", metavar="SET")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--yes", action="store_true")
    return parser


def resolve_features(profile, with_, without):
    unknown = [name for name in with_ + without if name not in FEATURES]
    if unknown:
        raise UsageError("unknown feature: " + ", ".join(unknown))
    chosen = set(PROFILES[profile]) | set(with_)
    chosen -= set(without)
    return [name for name in FEATURES if name in chosen]


def resolve_profile(options):
    if options.local and options.profile not in (None, "local"):
        raise UsageError("--local conflicts with --profile " + options.profile)
    profile = "local" if options.local else (options.profile or "standard")
    if profile == "local" and "ci" in options.with_:
        raise UsageError("ci edits tracked files: not available with the local profile")
    return profile


def parse(argv):
    options = build_parser().parse_args(argv)
    options.profile = resolve_profile(options)
    options.mode = "apply" if options.apply else "plan"
    options.features = resolve_features(options.profile, options.with_, options.without)
    if options.skills == "none" and "skills" in options.features:
        options.features.remove("skills")
    return options
