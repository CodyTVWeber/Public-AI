import os

from .steps_ci import ci_file_path
from .steps_files import template_path as forge_template

MARKER_BEGIN = "<!-- ai-guardrails:begin -->"
MARKER_END = "<!-- ai-guardrails:end -->"
NO_PIPELINE = "No pipeline jobs installed: local and Claude hooks are the guardrails."
ALWAYS_INSTALLED = ("scripts",)
PUBLIC_AI_VAR = '"$PUBLIC_AI_DIR"/skills/setup-repo/scripts/'
INSTALLED_LINES = {
    "rules": "Rules: `.claude/rules/` holds clean-code, ban-comments, small-mrs, docs-current-or-dated and research-latest-main.",
    "scripts": "Analyzer, size gate and git-command scanner: `scripts/clean-code/`.",
    "git-hooks": "Git hooks: pre-commit runs `check-clean-code.sh` (analyzer on staged lines), pre-push runs `pre-push-gate.sh` (branch size). Wired via {via}.",
    "claude-hooks": "Claude Code hooks in `{settings}`: PreToolUse(Bash) guard on push and MR create (size and clean code), PostToolUse docs lint and analyzer after edits, Stop analyzer.",
    "post-git-hook": "PostToolUse(Bash) `post-git-check.sh`: analyzer on each commit's lines, subject length, branch size, one-PR reminder after push, conflict files after merge or pull.",
    "ai-risk": "AI risk: `docs/rules/` holds risk tiers, merge policy (`conservative`, auto-merge off) and agent-stop rules; `scripts/ai-risk/` classifies a change.",
    "pr-template": "PR template: `{template}`; `scripts/clean-code/check-pr-body.sh` validates a body against it.",
    "approval-gate": "Approval gate: `scripts/guard/git-approval-guard.sh` (PreToolUse on Bash).",
    "privacy": "Privacy gate: `scripts/check-privacy.sh`; local patterns live in `<git-dir>/info/privacy-patterns` (`--strict` or `PRIVACY_REQUIRE_PATTERNS=1` blocks when missing).",
    "research-ref": "Research ref: `scripts/guard/research-ref.sh` (SessionStart) reports when the checkout is behind the default branch.",
    "ci": "CI: `{ci}` runs the same `scripts/clean-code/*` checks on every merge request.",
}
STACK_NOTES = {
    "node": "JS/TS: merge `assets/lint/eslint.clean-code.js` from the setup-repo skill into the flat ESLint config (max-params, max-depth, function size); relax it for tests and generated code.",
    "typescript": "TypeScript: keep `strict` on; the analyzer covers params, nesting and function length on changed lines.",
    "maven": "Maven: merge `assets/lint/detekt-clean-code.yml` into the detekt config for Kotlin; Java relies on the analyzer plus checkstyle.",
    "gradle": "Gradle: merge `assets/lint/detekt-clean-code.yml` into the detekt config for Kotlin; Java relies on the analyzer plus checkstyle.",
    "python": "Python: merge `assets/lint/ruff-clean-code.toml` into `pyproject.toml`.",
    "go": "Go: enable `funlen`, `gocyclo` and `nestif` in golangci-lint at warn first.",
    "rust": "Rust: enable clippy `too_many_arguments` and `cognitive_complexity`.",
    "ruby": "Ruby: set RuboCop `Metrics/MethodLength`, `Metrics/ParameterLists` and `Metrics/BlockNesting`.",
    "shell": "Shell: the analyzer covers function length, parameters and nesting; run shellcheck in the repo's own checks.",
}
FALLBACK_NOTE = "No known stack: pick a linter that can cap nesting depth, parameter count and function length."


def installed_block(ctx):
    template = forge_template(ctx.detected["git"]["forge"]) or "the forge's PR template"
    values = {"via": ctx.hooks_via, "template": template, "ci": ci_file_path(ctx) or "pipeline", "settings": ctx.settings_rel}
    lines = [text.format(**values) for name, text in INSTALLED_LINES.items() if name in ALWAYS_INSTALLED or ctx.on(name)]
    return "\n".join("- " + line for line in lines)


def skills_block(ctx):
    if not ctx.on("skills"):
        return "No skills linked."
    return ("Skills are symlinks `.claude/skills/<name>` (local, one `.git/info/exclude` entry per link) into a Public-AI clone at "
            "`$PUBLIC_AI_DIR`; set `" + ctx.options.skills + "`. Relink: `" + PUBLIC_AI_VAR + "link-skills.sh . --skills "
            + ctx.options.skills + "`.")


def stack_block(ctx):
    names = [stack["name"] for stack in ctx.detected["stacks"]]
    lines = [STACK_NOTES[name] for name in names if name in STACK_NOTES]
    return "\n".join("- " + line for line in lines) or FALLBACK_NOTE


def pipeline_block(ctx):
    path = ci_file_path(ctx)
    if not ctx.on("ci") or not path:
        return NO_PIPELINE
    return ("`" + path + "` runs the same `scripts/clean-code/*` checks on every merge request. CI is the control a PR cannot "
            "silently delete: keep these jobs required.")


def flags_line(ctx):
    options = ctx.options
    parts = ["--profile " + options.profile]
    if options.with_:
        parts.append("--with " + ",".join(options.with_))
    if options.without:
        parts.append("--without " + ",".join(options.without))
    if options.hooks_via != "auto":
        parts.append("--hooks-via " + options.hooks_via)
    if options.skills != "core":
        parts.append("--skills " + options.skills)
    return " ".join(parts)


def rerun_block(ctx):
    bootstrap = PUBLIC_AI_VAR + "bootstrap.sh . " + flags_line(ctx)
    return ("`" + bootstrap + " --plan`, then `--apply`. Check with `" + PUBLIC_AI_VAR + "verify-repo.sh .`. "
            "`--upgrade` re-applies files changed upstream and keeps locally modified ones. Differing files are kept unless `--force`.")


def approval_block(ctx):
    if not ctx.on("approval-gate"):
        return ""
    with open(os.path.join(ctx.assets, "AGENTS.approval.md")) as handle:
        return handle.read()


def render_section(ctx):
    with open(os.path.join(ctx.assets, "AGENTS.guardrails.md")) as handle:
        text = handle.read()
    values = {"INSTALLED": installed_block(ctx), "SKILLS": skills_block(ctx), "STACK_NOTES": stack_block(ctx),
              "PIPELINE": pipeline_block(ctx), "APPROVAL": approval_block(ctx), "RERUN": rerun_block(ctx)}
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", value)
    return text
