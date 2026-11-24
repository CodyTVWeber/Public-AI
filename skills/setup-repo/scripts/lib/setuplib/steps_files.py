import os

from .hookspec import specs_for
from .plan_model import Step, copy_step, copy_tree_files
from .settings_merge import merge_settings

CLONE_HINT = "no Public-AI clone beside this skill: copy the files by hand or run bootstrap from a clone"
EMPLOYER_HINT = ("set EMPLOYER_PATTERN in scripts/check-privacy.sh (or export PRIVACY_EMPLOYER_PATTERN) to enable the "
                 "employer-name check; it ships empty")
SETTINGS_PATH = ".claude/settings.json"


def source(ctx, rel):
    return os.path.join(ctx.public_root, rel) if ctx.public_root else None


def missing_clone(step_id):
    return [Step(step_id, "manual", "", CLONE_HINT)]


def settings_step(ctx, spec, groups):
    step_id, reason = spec
    path = ctx.dest(SETTINGS_PATH)
    result = merge_settings(path, specs_for(groups), dry_run=True)
    if result["status"] == "invalid":
        return Step(step_id, "manual", SETTINGS_PATH, "settings.json is not valid JSON: add the " + ", ".join(groups) + " hooks by hand")
    if result["status"] == "skip":
        return Step(step_id, "skip", SETTINGS_PATH, "hooks already registered")
    return Step(step_id, result["status"], SETTINGS_PATH, reason, run=lambda: merge_settings(path, specs_for(groups)))


def claude_hook_steps(ctx):
    steps = []
    if ctx.on("claude-hooks"):
        steps.append(settings_step(ctx, ("claude-hooks", "PreToolUse size guard, PostToolUse docs lint and analyzer, Stop analyzer"),
                                   ["guard", "docs-lint", "analyzer", "stop"]))
    if ctx.on("post-git-hook"):
        steps.append(settings_step(ctx, ("post-git-hook", "PostToolUse(Bash) check after git commit, push, merge and pull"),
                                   ["post-git"]))
    return steps


def approval_gate_steps(ctx):
    if not ctx.on("approval-gate"):
        return []
    src = source(ctx, "scripts/guard/git-approval-guard.sh")
    if not src:
        return missing_clone("approval-gate")
    spec = {"id": "approval-gate", "path": "scripts/guard/git-approval-guard.sh", "executable": True,
            "reason": "asks before every git commit and push, denies hook bypasses (for human-gated repos)"}
    return [copy_step(ctx, spec, src),
            settings_step(ctx, ("approval-gate-hook", "PreToolUse(Bash) approval gate"), ["approval-gate"])]


def research_ref_steps(ctx):
    if not ctx.on("research-ref"):
        return []
    src = source(ctx, "scripts/guard/research-ref.sh")
    if not src:
        return missing_clone("research-ref")
    spec = {"id": "research-ref", "path": "scripts/guard/research-ref.sh", "executable": True,
            "reason": "reports how far the checkout is behind the default branch"}
    return [copy_step(ctx, spec, src),
            settings_step(ctx, ("research-ref-hook", "SessionStart hook speaks up when the checkout is behind"), ["research-ref"])]


def privacy_steps(ctx):
    if not ctx.on("privacy"):
        return []
    if not ctx.public_root:
        return missing_clone("privacy")
    steps = []
    for name in ("check-privacy.sh", "install-hooks.sh"):
        spec = {"id": "privacy:" + name, "path": "scripts/" + name, "executable": True,
                "reason": "generic privacy gate (employer pattern ships empty)"}
        steps.append(copy_step(ctx, spec, source(ctx, "scripts/" + name)))
    steps.append(Step("privacy:employer-pattern", "manual", "scripts/check-privacy.sh", EMPLOYER_HINT))
    return steps


def ai_risk_steps(ctx):
    if not ctx.on("ai-risk"):
        return []
    base = source(ctx, "skills/ai-risk")
    if not base or not os.path.isdir(base):
        return missing_clone("ai-risk")
    steps = []
    for name in copy_tree_files(os.path.join(base, "rules"), ".md"):
        spec = {"id": "ai-risk:" + name, "path": "docs/rules/" + name, "reason": "risk tiers, merge policy and agent-stop rules"}
        steps.append(copy_step(ctx, spec, os.path.join(base, "rules", name)))
    policy = {"id": "ai-risk:policy", "path": "docs/rules/ai-merge-policy.md",
              "reason": "declares the merge policy: conservative, auto-merge off"}
    steps.append(copy_step(ctx, policy, os.path.join(base, "assets", "ai-merge-policy.md")))
    for name in ("classify-tier.sh", "merge-policy.sh"):
        spec = {"id": "ai-risk:" + name, "path": "scripts/ai-risk/" + name, "executable": True, "reason": "risk tier and policy lookup"}
        steps.append(copy_step(ctx, spec, os.path.join(base, "scripts", name)))
    return steps


def template_path(forge):
    return {"gitlab": ".gitlab/merge_request_templates/default.md", "github": ".github/pull_request_template.md"}.get(forge)


def pr_template_steps(ctx):
    if not ctx.on("pr-template"):
        return []
    base = source(ctx, "skills/verify-change")
    if not base or not os.path.isdir(base):
        return missing_clone("pr-template")
    path = template_path(ctx.detected["git"]["forge"])
    steps = [Step("pr-template", "manual", "", "no GitLab or GitHub remote: place assets/pr-body.md as the forge's PR template by hand")]
    if path:
        spec = {"id": "pr-template", "path": path, "reason": "PR/MR description template with the review guide, risk and proof sections"}
        steps = [copy_step(ctx, spec, os.path.join(base, "assets", "pr-body.md"))]
    spec = {"id": "pr-template:check", "path": "scripts/clean-code/check-pr-body.sh", "executable": True,
            "reason": "validates a PR body against the template"}
    return steps + [copy_step(ctx, spec, os.path.join(base, "scripts", "check-pr-body.sh"))]


def addon_file_steps(ctx):
    return privacy_steps(ctx) + approval_gate_steps(ctx) + research_ref_steps(ctx) + ai_risk_steps(ctx) + pr_template_steps(ctx)
