import json
import os
import sys

from .bs_options import UsageError, parse
from .detect_cli import build_profile
from .doc_render import NO_PIPELINE
from .plan_model import Context
from .repo import Repo
from .steps_ci import CONTROL_NOTE, ci_steps
from .steps_core import core_steps
from .steps_doc import doc_steps, manifest_step
from .steps_files import addon_file_steps, claude_hook_steps
from .steps_hooks import hook_steps, resolve_hooks_via
from .steps_skills import skills_steps

SKILL_DIR = os.path.realpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PRECONDITION_ERROR = 3
ACTION_COLUMN = 6
ACTIONS = ("create", "merge", "skip", "manual")


def find_public_root():
    root = os.path.realpath(os.path.join(SKILL_DIR, "..", ".."))
    marker = os.path.join(root, "scripts", "check-privacy.sh")
    return root if os.path.isdir(os.path.join(root, "skills", "ai-risk")) and os.path.isfile(marker) else None


def build_context(options):
    repo = Repo(options.target)
    detected = build_profile(repo, False)
    via, note = resolve_hooks_via(options, detected)
    return Context(options=options, repo=repo, detected=detected, features=options.features, hooks_via=via,
                   hooks_note=note, skill_dir=SKILL_DIR, public_root=find_public_root())


def build_steps(ctx):
    steps = core_steps(ctx) + addon_file_steps(ctx) + hook_steps(ctx) + claude_hook_steps(ctx)
    return steps + ci_steps(ctx) + skills_steps(ctx) + doc_steps(ctx) + [manifest_step(ctx)]


def run_steps(steps):
    for step in steps:
        if step.action not in ("create", "merge") or step.run is None:
            continue
        try:
            step.run()
            step.result = "done"
        except Exception as error:
            step.result = "failed: " + str(error)[:200]


def summarize(steps):
    counts = {name: sum(1 for step in steps if step.action == name) for name in ACTIONS}
    counts["failed"] = sum(1 for step in steps if (step.result or "").startswith("failed"))
    return counts


def plan_notes(ctx):
    notes = list(ctx.detected["recommend"]["notes"])
    if ctx.on("ci"):
        notes.append(CONTROL_NOTE)
    else:
        notes.append(NO_PIPELINE)
    if ctx.on("approval-gate"):
        notes.append("approval-gate is for human-gated repos: every commit and push waits for approval; unattended factories leave it off")
    return notes


def print_digest(steps, summary, mode):
    counts = ", ".join(str(summary[name]) + " " + name for name in ACTIONS)
    print("bootstrap " + mode + ": " + counts, file=sys.stderr)
    for step in steps:
        if step.action in ("manual", "create", "merge"):
            print("  " + step.action.ljust(ACTION_COLUMN) + " " + step.id + " " + step.path, file=sys.stderr)
        if step.action == "manual":
            print("         " + step.reason, file=sys.stderr)


def check_target(options):
    if not os.path.isdir(options.target):
        print("bootstrap: not a directory: " + options.target, file=sys.stderr)
        return PRECONDITION_ERROR
    if not os.path.exists(os.path.join(options.target, ".git")):
        print("bootstrap: not a git repo: " + options.target, file=sys.stderr)
        return PRECONDITION_ERROR
    return 0


def main(argv):
    try:
        options = parse(argv)
    except UsageError as error:
        print("bootstrap: " + str(error), file=sys.stderr)
        return 2
    failure = check_target(options)
    if failure:
        return failure
    ctx = build_context(options)
    steps = build_steps(ctx)
    changes = [step for step in steps if step.action in ("create", "merge")]
    if options.mode == "apply" and changes and ctx.detected["git"]["dirty"] and not options.yes:
        print("bootstrap: working tree has uncommitted changes; rerun with --yes to apply anyway", file=sys.stderr)
        return PRECONDITION_ERROR
    if options.mode == "apply":
        run_steps(steps)
    summary = summarize(steps)
    result = {"target": ctx.root, "mode": options.mode, "applied": options.mode == "apply", "profile": options.profile,
              "features": ctx.features, "hooks_via": ctx.hooks_via, "steps": [step.public() for step in steps],
              "summary": summary, "notes": plan_notes(ctx)}
    print(json.dumps(result, indent=2))
    print_digest(steps, summary, options.mode)
    return 1 if summary["failed"] else 0
