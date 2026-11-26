import os

from .hook_snippets import (OWN_MARKER, SHEBANG, calls_snippet, husky_lines, husky_marker, lefthook_snippet,
                            native_body, precommit_snippet)
from .plan_model import Step, make_executable, write_bytes
from .steps_core import githooks_steps

GIT_HOOK_NAMES = ("pre-commit", "pre-push")
PRIVACY_HOOK = "commit-msg"


NO_NOTE = {"text": "", "manual": False}


def local_hooks_via(options, systems):
    if options.hooks_via == "none":
        return "none", NO_NOTE
    path = systems.get("core.hooksPath")
    if path:
        return "none", {"text": "core.hooksPath is " + path + ": hooks in .git/hooks would not run and the local profile never sets it",
                        "manual": True}
    return "native", NO_NOTE


def resolve_hooks_via(options, detected):
    systems = {item["name"]: item["detail"] for item in detected["hook_systems"]}
    if options.profile == "local":
        return local_hooks_via(options, systems)
    via, note = options.hooks_via, NO_NOTE
    if via == "auto":
        via, note = detected["recommend"]["hooks_via"], recommended_note(detected, systems)
    if via == "githooks":
        return githooks_variant(systems)
    return via, note


def githooks_variant(systems):
    path = systems.get("core.hooksPath", ".githooks")
    if path != ".githooks":
        return "none", {"text": "core.hooksPath is " + path + ": never overridden", "manual": True}
    if "native" in systems or "native-own" in systems:
        detail = systems.get("native", systems.get("native-own"))
        return "native", {"text": "git hooks in .git/hooks (" + detail + ") are chained, foreign ones kept as .bak", "manual": False}
    return "githooks", NO_NOTE


def recommended_note(detected, systems):
    if detected["recommend"]["hooks_via"] != "none":
        return NO_NOTE
    reason = next((flag["reason"] for flag in detected["recommend"]["flags"] if flag["flag"].startswith("--hooks-via")), "")
    manual = systems.get("core.hooksPath", ".githooks") != ".githooks" or "simple-git-hooks" in systems
    return {"text": reason, "manual": manual}


def privacy_wanted(ctx):
    return ctx.on("privacy") or os.path.isfile(ctx.dest("scripts/check-privacy.sh"))


def hook_names(ctx):
    return GIT_HOOK_NAMES + ((PRIVACY_HOOK,) if privacy_wanted(ctx) else ())


def append_step(ctx, hook):
    rel = ".husky/" + hook
    lines = husky_lines(hook, privacy_wanted(ctx))
    if not lines:
        return None
    dest = ctx.dest(rel)
    text = open(dest).read() if os.path.exists(dest) else None
    if text is not None and husky_marker(hook) in text:
        return Step("git-hooks:" + hook, "skip", rel, "husky hook already calls the clean-code scripts")
    action = "merge" if text is not None else "create"
    return Step("git-hooks:" + hook, action, rel, "husky hook gets the clean-code call lines",
                run=lambda: write_husky(dest, text, lines))


def write_husky(dest, text, lines):
    body = "\n".join(lines) + "\n"
    if text is None:
        write_bytes(dest, (SHEBANG + "\n" + body).encode(), True)
        return
    separator = "" if text.endswith("\n") else "\n"
    write_bytes(dest, (text + separator + body).encode(), True)


def husky_steps(ctx):
    steps = [append_step(ctx, hook) for hook in hook_names(ctx)]
    return [step for step in steps if step]


def hooks_dir(ctx):
    out = (ctx.repo.git("rev-parse", "--git-path", "hooks") or ".git/hooks").strip()
    return out if out.startswith("/") else os.path.join(ctx.root, out)


def display_path(ctx, path):
    rel = os.path.relpath(path, ctx.root)
    return path if rel.startswith("..") else rel


def native_step(ctx, hook):
    path = os.path.join(hooks_dir(ctx), hook)
    body = native_body(hook, privacy_wanted(ctx))
    shown = display_path(ctx, path)
    existing = open(path, errors="replace").read() if os.path.exists(path) else None
    step_id = "git-hooks:" + hook
    if existing == body:
        return Step(step_id, "skip", shown, "hook already chains the clean-code checks")
    if existing is not None and OWN_MARKER not in existing:
        return native_foreign_step(step_id, (path, shown), (existing, body))
    action = "merge" if existing else "create"
    return Step(step_id, action, shown, "git hook runs the clean-code checks", run=lambda: install_native(path, body))


def native_foreign_step(step_id, paths, texts):
    path, shown = paths
    existing, body = texts
    if "scripts/clean-code" in existing:
        return Step(step_id, "skip", shown, "existing hook already calls the clean-code scripts")
    if os.path.exists(path + ".bak"):
        return Step(step_id, "manual", shown, "foreign hook exists and " + os.path.basename(path) + ".bak is taken: move one aside")
    return Step(step_id, "merge", shown, "foreign hook kept as " + os.path.basename(path) + ".bak, still runs after the checks",
                run=lambda: install_native(path, body, backup=True))


def install_native(path, body, backup=False):
    if backup:
        os.replace(path, path + ".bak")
        make_executable(path + ".bak")
    write_bytes(path, body.encode(), True)


def snippet_step(name, path, snippet):
    reason = name + " owns the hooks: add this by hand (the plan never rewrites its config)"
    return [Step("git-hooks", "manual", path, reason, extra={"snippet": snippet})]


def hook_steps(ctx):
    if not ctx.on("git-hooks"):
        return []
    privacy = privacy_wanted(ctx)
    via = ctx.hooks_via
    if via == "githooks":
        return githooks_steps(ctx)
    if via == "husky":
        return husky_steps(ctx)
    if via == "native":
        return [native_step(ctx, hook) for hook in hook_names(ctx)]
    if via == "lefthook":
        return snippet_step("lefthook", "lefthook.yml", lefthook_snippet(privacy))
    if via == "precommit":
        return snippet_step("pre-commit framework", ".pre-commit-config.yaml", precommit_snippet(privacy))
    note = ctx.hooks_note
    reason = note["text"] or "hooks-via none: the repo's own hook setup runs the checks"
    action = "manual" if note["manual"] else "skip"
    return [Step("git-hooks", action, "", reason, extra={"snippet": calls_snippet(privacy)} if note["manual"] else {})]
