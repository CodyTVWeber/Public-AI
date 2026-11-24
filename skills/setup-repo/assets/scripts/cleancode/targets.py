import os
from dataclasses import dataclass

from .gitdiff import GitError, base_ref, diff_changes, everything, git, require_root
from .languages import spec_for

MAX_BYTES = 2_000_000


@dataclass
class Target:
    path: str
    text: str
    change: object


@dataclass(frozen=True)
class FileOptions:
    skip_ignored: bool = False
    all_lines: bool = False
    require_repo: bool = False


def read_worktree(root, path):
    full = os.path.join(root, path)
    if not os.path.isfile(full) or os.path.getsize(full) > MAX_BYTES:
        return None
    with open(full, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def read_blob(root, ref, path):
    code, out = git(root, "show", "%s:%s" % (ref, path))
    return out if code == 0 and len(out) <= MAX_BYTES else None


def build_targets(changes, reader):
    targets = []
    for path, change in sorted(changes.items()):
        text = reader(path) if spec_for(path) else None
        if text is not None:
            targets.append(Target(path, text, change))
    return targets


def staged_targets(cwd):
    root = require_root(cwd)
    changes = diff_changes(root, ["--cached", base_ref(root)])
    return build_targets(changes, lambda path: read_blob(root, "", path))


def merge_base(root, base, head="HEAD"):
    code, _ = git(root, "rev-parse", "--verify", "-q", base + "^{commit}")
    if code != 0:
        raise GitError("unknown base: " + base)
    code, out = git(root, "merge-base", base, head)
    return out.strip() if code == 0 and out.strip() else base


def untracked_paths(root):
    _, out = git(root, "ls-files", "-o", "--exclude-standard", "-z")
    return [path for path in out.split("\0") if path]


def tracked_changes(root, base):
    reference = base_ref(root) if base == "HEAD" else merge_base(root, base)
    return diff_changes(root, [reference])


def tracked_targets(cwd):
    root = require_root(cwd)
    changes = tracked_changes(root, "HEAD")
    return build_targets(changes, lambda path: read_worktree(root, path))


def changed_targets(cwd, base):
    root = require_root(cwd)
    changes = tracked_changes(root, base)
    for path in untracked_paths(root):
        changes[path] = everything()
    return build_targets(changes, lambda path: read_worktree(root, path))


def split_range(spec):
    for dots in ("...", ".."):
        if dots in spec:
            start, _, end = spec.partition(dots)
            return start, end or "HEAD", dots == "..."
    raise GitError("range must look like BASE..HEAD: " + spec)


def verify_ref(root, ref, kind):
    code, _ = git(root, "rev-parse", "--verify", "-q", "%s^{%s}" % (ref, kind))
    if code != 0:
        raise GitError("unknown ref: " + ref)


def range_targets(cwd, spec):
    root = require_root(cwd)
    start, end, symmetric = split_range(spec)
    verify_ref(root, end, "commit")
    verify_ref(root, start, "tree")
    if symmetric:
        start = merge_base(root, start, end)
    changes = diff_changes(root, [start, end])
    return build_targets(changes, lambda path: read_blob(root, end, path))
