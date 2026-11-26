import os
import subprocess

STALE_COPY = "stale-copy"
GIT_TIMEOUT_SECONDS = 20


def git_out(cwd, *args):
    try:
        result = subprocess.run(["git", "-C", cwd] + list(args), capture_output=True, text=True,
                                timeout=GIT_TIMEOUT_SECONDS)
    except (OSError, subprocess.SubprocessError):
        return ""
    return result.stdout if result.returncode == 0 else ""


def past_blobs(src):
    folder = os.path.dirname(src)
    top = git_out(folder, "rev-parse", "--show-toplevel").strip()
    if not top:
        return set()
    rel = os.path.relpath(os.path.realpath(src), os.path.realpath(top))
    raw = git_out(top, "log", "--follow", "--format=", "--raw", "--no-abbrev", "--", rel)
    fields = [line.split() for line in raw.splitlines() if line.startswith(":")]
    return {parts[3] for parts in fields if len(parts) > 3}


def is_stale_copy(src, dest):
    if not os.path.isfile(src) or not os.path.isfile(dest):
        return False
    blob = git_out(os.path.dirname(src), "hash-object", "--", dest).strip()
    return bool(blob) and blob in past_blobs(src)


def take_stale(ctx, item):
    if ctx.drift_map.get(item["path"]) or not is_stale_copy(item["src"], ctx.dest(item["path"])):
        return None
    if ctx.options.upgrade:
        ctx.upgrade_paths.add(item["path"])
        ctx.installed[item["path"]] = item["src"]
    return STALE_COPY
