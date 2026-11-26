import os

from .exclude import block_needed, write_block
from .plan_model import Step, write_bytes
from .record import LOCAL_NOTE_RELATIVE, git_path

EXCLUDE_TAG = "local"
SETTINGS_ENTRY = ".claude/settings.local.json"
SCRIPTS_DIR = "scripts/clean-code/"
SETTINGS_FEATURES = ("claude-hooks", "post-git-hook", "approval-gate", "research-ref")
NOTE_HEADER = ("<!-- Local guardrails note: written to the git dir, not to AGENTS.md, so tracked files stay unchanged. -->\n\n")


def shown(ctx, path):
    return os.path.relpath(path, ctx.root) if path.startswith(ctx.root + os.sep) else path


def read_text(path):
    try:
        with open(path) as handle:
            return handle.read()
    except OSError:
        return None


def local_doc_step(ctx, section):
    dest = git_path(ctx.root, LOCAL_NOTE_RELATIVE)
    text = NOTE_HEADER + section
    current = read_text(dest)
    if current == text:
        return Step("agents-doc", "skip", shown(ctx, dest), "local guardrails note is current")
    action = "create" if current is None else "merge"
    return Step("agents-doc", action, shown(ctx, dest), "writes the guardrails note to the git dir; AGENTS.md stays unchanged",
                run=lambda: write_bytes(dest, text.encode(), False))


def exclude_entries(ctx):
    entries = {SETTINGS_ENTRY} if any(ctx.on(name) for name in SETTINGS_FEATURES) else set()
    for path in ctx.installed:
        entries.add(SCRIPTS_DIR if path.startswith(SCRIPTS_DIR) else path)
    return sorted(entries)


def exclude_step(ctx):
    if not ctx.local:
        return []
    entries = exclude_entries(ctx)
    path = shown(ctx, os.path.join(os.path.dirname(git_path(ctx.root, LOCAL_NOTE_RELATIVE)), "exclude"))
    if not block_needed(ctx.root, EXCLUDE_TAG, entries):
        return [Step("exclude", "skip", path, "installed paths already excluded")]
    return [Step("exclude", "merge", path, "excludes " + str(len(entries)) + " installed paths so git status stays clean",
                 run=lambda: write_block(ctx.root, EXCLUDE_TAG, entries))]
