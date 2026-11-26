import json
import os
import subprocess

from .drift import file_hash
from .sources import source_root, source_sha

STANDARD_PATH = ".claude/ai-guardrails.json"
LOCAL_RELATIVE = "info/local-guardrails.json"
LOCAL_NOTE_RELATIVE = "info/local-guardrails.md"


def git_path(root, relative):
    out = subprocess.run(["git", "-C", root, "rev-parse", "--git-path", relative], capture_output=True, text=True)
    path = out.stdout.strip()
    return path if path.startswith("/") else os.path.join(root, path)


def record_path(root, local):
    return git_path(root, LOCAL_RELATIVE) if local else os.path.join(root, STANDARD_PATH)


def read_json(path):
    try:
        with open(path) as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def load_record(root):
    return read_json(git_path(root, LOCAL_RELATIVE)) or read_json(os.path.join(root, STANDARD_PATH))


def file_entries(ctx, previous):
    base = source_root()
    kept = ((previous or {}).get("files") or {}).items()
    files = {path: entry for path, entry in kept if os.path.exists(os.path.join(ctx.root, path))}
    for path, src in sorted(ctx.installed.items()):
        files[path] = {"hash": file_hash(src), "source": os.path.relpath(src, base)}
    return files


def build_record(ctx):
    options = ctx.options
    previous = load_record(ctx.root)
    return {"tool": "setup-repo", "mode": "local" if ctx.local else "standard", "profile": options.profile,
            "features": ctx.features, "hooks_via": ctx.hooks_via, "skills": options.skills if ctx.on("skills") else "none",
            "source_sha": source_sha(source_root()), "files": file_entries(ctx, previous)}
