import hashlib
import os

from .stale import STALE_COPY

CHANGED_UPSTREAM = "changed-upstream"
MODIFIED_LOCALLY = "modified-locally"
MISSING = "missing"
REMOVED_UPSTREAM = "removed-upstream"
READ_CHUNK = 65536


def file_hash(path):
    digest = hashlib.sha256()
    try:
        with open(path, "rb") as handle:
            for chunk in iter(lambda: handle.read(READ_CHUNK), b""):
                digest.update(chunk)
    except OSError:
        return None
    return digest.hexdigest()


def entry_status(places, path, entry):
    root, source_base = places
    installed = file_hash(os.path.join(root, path))
    if installed is None:
        return MISSING
    upstream = file_hash(os.path.join(source_base, entry["source"]))
    if installed == upstream:
        return None
    if installed != entry["hash"]:
        return MODIFIED_LOCALLY
    return CHANGED_UPSTREAM if upstream is not None else REMOVED_UPSTREAM


def compute_drift(root, record, source_base):
    found = []
    for path, entry in sorted(((record or {}).get("files") or {}).items()):
        status = entry_status((root, source_base), path, entry)
        if status:
            found.append({"path": path, "status": status})
    return found


def differs_reason(drift_map, path, stale=None):
    status = drift_map.get(path) or stale
    if status == STALE_COPY:
        return "unchanged copy of an earlier upstream version: rerun with --upgrade to replace it"
    if status == CHANGED_UPSTREAM:
        return "changed upstream since install: rerun with --upgrade (or --force) to take the new version"
    if status == MODIFIED_LOCALLY:
        return "modified locally since install: kept; diff it, or rerun with --force to overwrite"
    return "exists and differs: diff it and keep the stricter value, or rerun with --force"
