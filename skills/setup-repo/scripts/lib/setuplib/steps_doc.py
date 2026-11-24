import json
import os
import re

from .doc_render import MARKER_BEGIN, MARKER_END, render_section
from .plan_model import Step, write_bytes

POINTER_MAX_LINES = 3
POINTER_TEXT = "@AGENTS.md\n"
SECTION_PATTERN = re.compile(re.escape(MARKER_BEGIN) + r".*?" + re.escape(MARKER_END) + "\n?", re.S)
MANIFEST_PATH = ".claude/ai-guardrails.json"


def read_text(path):
    try:
        with open(path) as handle:
            return handle.read()
    except OSError:
        return None


def is_pointer(text):
    lines = [line for line in (text or "").splitlines() if line.strip()]
    return any(line.strip() == "@AGENTS.md" for line in lines) and len(lines) <= POINTER_MAX_LINES


def pick_doc(ctx):
    agents, claude = read_text(ctx.dest("AGENTS.md")), read_text(ctx.dest("CLAUDE.md"))
    if agents is not None:
        return "AGENTS.md", agents, False
    if claude is not None and not is_pointer(claude):
        return "CLAUDE.md", claude, False
    return "AGENTS.md", None, claude is None


def merge_section(current, section):
    if current is None:
        return "# AGENTS.md\n\n" + section
    if SECTION_PATTERN.search(current):
        return SECTION_PATTERN.sub(lambda _: section, current, count=1)
    return current.rstrip("\n") + "\n\n" + section


def doc_steps(ctx):
    if not ctx.on("agents-doc"):
        return []
    name, current, needs_pointer = pick_doc(ctx)
    updated = merge_section(current, render_section(ctx))
    steps = []
    if updated == current:
        steps.append(Step("agents-doc", "skip", name, "AI guardrails section is current"))
    else:
        action = "create" if current is None else "merge"
        reason = "adds the AI guardrails section" if current is None or MARKER_BEGIN not in current else "refreshes the AI guardrails section"
        steps.append(Step("agents-doc", action, name, reason, run=lambda: write_bytes(ctx.dest(name), updated.encode(), False)))
    if needs_pointer:
        steps.append(Step("agents-doc:pointer", "create", "CLAUDE.md", "pointer to AGENTS.md; rules live in AGENTS.md",
                          run=lambda: write_bytes(ctx.dest("CLAUDE.md"), POINTER_TEXT.encode(), False)))
    return steps


def manifest_data(ctx):
    options = ctx.options
    return {"tool": "setup-repo", "profile": options.profile, "features": ctx.features, "hooks_via": ctx.hooks_via,
            "skills": options.skills if ctx.on("skills") else "none"}


def manifest_step(ctx):
    text = json.dumps(manifest_data(ctx), indent=2) + "\n"
    current = read_text(ctx.dest(MANIFEST_PATH))
    if current == text:
        return Step("manifest", "skip", MANIFEST_PATH, "install record is current")
    action = "create" if current is None else "merge"
    return Step("manifest", action, MANIFEST_PATH, "records profile and features for verify-repo.sh",
                run=lambda: write_bytes(ctx.dest(MANIFEST_PATH), text.encode(), False))
