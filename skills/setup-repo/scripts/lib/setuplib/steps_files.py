import os

from .hookspec import specs_for
from .plan_model import Step, copy_tree_files
from .settings_merge import merge_settings
from .steps_copy import copy_steps

CLONE_HINT = "no Public-AI clone beside this skill: copy the files by hand or run bootstrap from a clone"
PATTERNS_HINT = ("create <git-dir>/info/privacy-patterns (untracked, one extended regex per line: employer names, internal "
                 "hostnames); a missing file warns, and blocks with scripts/check-privacy.sh --strict or PRIVACY_REQUIRE_PATTERNS=1")
PRIVACY_REASON = "generic privacy gate; local patterns come from <git-dir>/info/privacy-patterns"


def source(ctx, rel):
    return os.path.join(ctx.public_root, rel) if ctx.public_root else None


def missing_clone(step_id):
    return [Step(step_id, "manual", "", CLONE_HINT)]


def settings_step(ctx, spec, groups):
    step_id, reason = spec
    rel = ctx.settings_rel
    path = ctx.dest(rel)
    result = merge_settings(path, specs_for(groups), dry_run=True)
    if result["status"] == "invalid":
        return Step(step_id, "manual", rel, rel + " is not valid JSON: add the " + ", ".join(groups) + " hooks by hand")
    if result["status"] == "skip":
        return Step(step_id, "skip", rel, "hooks already registered")
    return Step(step_id, result["status"], rel, reason, run=lambda: merge_settings(path, specs_for(groups)))


def claude_hook_steps(ctx):
    steps = []
    if ctx.on("claude-hooks"):
        steps.append(settings_step(ctx, ("claude-hooks", "PreToolUse size guard, PostToolUse docs lint and analyzer, Stop analyzer"),
                                   ["guard", "docs-lint", "analyzer", "stop"]))
    if ctx.on("post-git-hook"):
        steps.append(settings_step(ctx, ("post-git-hook", "PostToolUse(Bash) check after git commit, push, merge and pull"),
                                   ["post-git"]))
    return steps


GUARD_REASONS = {"approval-gate": "asks before every git commit and push, denies hook bypasses (for human-gated repos)",
                 "research-ref": "reports how far the checkout is behind the default branch"}


def guard_spec(ctx, step_id, name):
    return {"id": step_id, "path": "scripts/guard/" + name, "src": source(ctx, "scripts/guard/" + name),
            "reason": GUARD_REASONS[step_id]}


def approval_gate_steps(ctx):
    if not ctx.on("approval-gate"):
        return []
    if not ctx.public_root:
        return missing_clone("approval-gate")
    spec = guard_spec(ctx, "approval-gate", "git-approval-guard.sh")
    return copy_steps(ctx, [spec]) + [settings_step(ctx, ("approval-gate-hook", "PreToolUse(Bash) approval gate"), ["approval-gate"])]


def research_ref_steps(ctx):
    if not ctx.on("research-ref"):
        return []
    if not ctx.public_root:
        return missing_clone("research-ref")
    spec = guard_spec(ctx, "research-ref", "research-ref.sh")
    return copy_steps(ctx, [spec]) + [settings_step(ctx, ("research-ref-hook", "SessionStart hook speaks up when the checkout is behind"),
                                                    ["research-ref"])]


def privacy_steps(ctx):
    if not ctx.on("privacy"):
        return []
    if not ctx.public_root:
        return missing_clone("privacy")
    specs = [{"id": "privacy:" + name, "path": "scripts/" + name, "src": source(ctx, "scripts/" + name), "reason": PRIVACY_REASON}
             for name in ("check-privacy.sh", "install-hooks.sh")]
    return copy_steps(ctx, specs) + [Step("privacy:patterns", "manual", "scripts/check-privacy.sh", PATTERNS_HINT)]


def ai_risk_steps(ctx):
    if not ctx.on("ai-risk"):
        return []
    base = source(ctx, "skills/ai-risk")
    if not base or not os.path.isdir(base):
        return missing_clone("ai-risk")
    specs = [{"id": "ai-risk:" + name, "path": "docs/rules/" + name, "src": os.path.join(base, "rules", name),
              "reason": "risk tiers, merge policy and agent-stop rules"} for name in copy_tree_files(os.path.join(base, "rules"), ".md")]
    specs.append({"id": "ai-risk:policy", "path": "docs/rules/ai-merge-policy.md", "src": os.path.join(base, "assets", "ai-merge-policy.md"),
                  "reason": "declares the merge policy: conservative, auto-merge off"})
    specs += [{"id": "ai-risk:" + name, "path": "scripts/ai-risk/" + name, "src": os.path.join(base, "scripts", name),
               "reason": "risk tier and policy lookup"} for name in ("classify-tier.sh", "merge-policy.sh")]
    return copy_steps(ctx, specs)


def template_path(forge):
    return {"gitlab": ".gitlab/merge_request_templates/default.md", "github": ".github/pull_request_template.md"}.get(forge)


def pr_template_steps(ctx):
    if not ctx.on("pr-template"):
        return []
    base = source(ctx, "skills/verify-change")
    if not base or not os.path.isdir(base):
        return missing_clone("pr-template")
    path = template_path(ctx.detected["git"]["forge"])
    specs = [{"id": "pr-template:check", "path": "scripts/clean-code/check-pr-body.sh", "src": os.path.join(base, "scripts", "check-pr-body.sh"),
              "reason": "validates a PR body against the template"}]
    if not path:
        return [Step("pr-template", "manual", "", "no GitLab or GitHub remote: place assets/pr-body.md as the forge's PR template by hand")] + copy_steps(ctx, specs)
    specs.insert(0, {"id": "pr-template", "path": path, "src": os.path.join(base, "assets", "pr-body.md"),
                     "reason": "PR/MR description template with the review guide, risk and proof sections"})
    return copy_steps(ctx, specs)


def addon_file_steps(ctx):
    return privacy_steps(ctx) + approval_gate_steps(ctx) + research_ref_steps(ctx) + ai_risk_steps(ctx) + pr_template_steps(ctx)
