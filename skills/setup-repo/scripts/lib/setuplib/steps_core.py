import json
import os
import subprocess

from .plan_model import Step

INSTALL_TIMEOUT_SECONDS = 120
GROUP_PREFIXES = (("rules", ".claude/rules/"), ("scripts", "scripts/clean-code/"), ("git-hooks", ".githooks/"))


def githooks_active(ctx):
    return ctx.on("git-hooks") and ctx.hooks_via == "githooks"


def install_flags(ctx):
    flags = ["--no-claude-hook", "--no-doc"]
    if not ctx.on("rules"):
        flags.append("--no-rules")
    if not githooks_active(ctx):
        flags.append("--no-githooks")
    if ctx.options.force:
        flags.append("--force")
    return flags


def call_install(ctx, extra):
    command = [os.path.join(ctx.skill_dir, "scripts", "install.sh"), ctx.root] + install_flags(ctx) + extra
    result = subprocess.run(command, capture_output=True, text=True, timeout=INSTALL_TIMEOUT_SECONDS)
    if result.returncode != 0:
        raise RuntimeError("install.sh failed: " + result.stderr.strip()[-300:])
    return json.loads(result.stdout)


def core_preview(ctx):
    if "preview" not in ctx.cache:
        ctx.cache.update(preview=call_install(ctx, ["--dry-run"]))
    return ctx.cache["preview"]


def run_core(ctx):
    if "applied" not in ctx.cache:
        ctx.cache.update(applied=call_install(ctx, []))


def group_files(preview, prefix):
    return [item for item in preview["files"] if item["path"].startswith(prefix)]


def group_steps(ctx, spec, files):
    step_id, reason = spec
    if not files:
        return []
    differing = [item for item in files if item["status"] == "differs"]
    written = [item for item in files if item["status"] in ("create", "overwrite")]
    steps = [Step(step_id + ":" + item["path"], "manual", item["path"],
                  "exists and differs: diff it and keep the stricter value, or rerun with --force") for item in differing]
    path = files[0]["path"].rsplit("/", 1)[0] + "/"
    if written:
        steps.insert(0, Step(step_id, "create", path, reason + " (" + str(len(written)) + " files)", run=lambda: run_core(ctx)))
    elif not differing:
        steps.insert(0, Step(step_id, "skip", path, "all " + str(len(files)) + " files already installed and identical"))
    return steps


def core_steps(ctx):
    preview = core_preview(ctx)
    steps = []
    if ctx.on("rules"):
        steps += group_steps(ctx, ("rules", "clean-code, ban-comments, small-MR, docs and research rules"),
                             group_files(preview, GROUP_PREFIXES[0][1]))
    steps += group_steps(ctx, ("scripts", "analyzer, size gate, git guards and git-command scanner"),
                         group_files(preview, GROUP_PREFIXES[1][1]))
    return steps


def githooks_steps(ctx):
    preview = core_preview(ctx)
    files = group_files(preview, GROUP_PREFIXES[2][1])
    steps = group_steps(ctx, ("git-hooks", "git pre-commit and pre-push via core.hooksPath=.githooks"), files)
    status = preview["git_hooks"]["status"]
    if status == "foreign":
        steps.append(Step("git-hooks:hooks-path", "manual", "core.hooksPath", preview["git_hooks"]["note"]))
    elif status == "set" and steps and steps[0].action == "skip":
        steps[0] = Step("git-hooks", "merge", "core.hooksPath", "sets core.hooksPath=.githooks", run=lambda: run_core(ctx))
    return steps
