import os

from .drift import MISSING, compute_drift
from .repo import run_git
from .sources import source_root
from .verify_common import is_local, result

SETTINGS_LOCAL = ".claude/settings.local.json"
LINK_DIR = ".claude/skills"
STATUS_COLUMNS = 3


def drift_of(root, manifest):
    return compute_drift(root, manifest, source_root()) if manifest and manifest.get("files") else []


def check_drift(drift, manifest):
    if not manifest or not manifest.get("files"):
        return result("drift", "skip", "the install record lists no copied files")
    if not drift:
        return result("drift", "pass", str(len(manifest["files"])) + " installed files match the record and the source")
    missing = [item["path"] for item in drift if item["status"] == MISSING]
    detail = "; ".join(item["path"] + " " + item["status"] for item in drift)
    return result("drift", "fail" if missing else "warn", detail)


def installed_paths(root, manifest):
    paths = set(manifest.get("files") or {}) | {SETTINGS_LOCAL}
    base = os.path.join(root, LINK_DIR)
    if os.path.isdir(base):
        paths |= {LINK_DIR + "/" + name for name in os.listdir(base) if os.path.islink(os.path.join(base, name))}
    return paths


def porcelain_paths(root):
    out = run_git(root, ["status", "--porcelain", "--untracked-files=all"]) or ""
    return [line[STATUS_COLUMNS:].split(" -> ")[-1].strip('"') for line in out.splitlines() if len(line) > STATUS_COLUMNS]


def check_local_clean(root, manifest):
    if not is_local(manifest):
        return result("local-clean", "skip", "not the local profile")
    wanted = installed_paths(root, manifest)
    shown = [path for path in porcelain_paths(root) if path in wanted]
    if shown:
        return result("local-clean", "fail", "installed paths show in git status: " + ", ".join(sorted(shown)))
    return result("local-clean", "pass", "git status lists no installed path")
