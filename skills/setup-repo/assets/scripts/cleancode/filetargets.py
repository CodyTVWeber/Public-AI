import os

from .gitdiff import FileChange, base_ref, diff_changes, everything, git
from .languages import spec_for
from .targets import FileOptions, Target, read_worktree


def find_root(directory):
    current = directory
    while not os.path.exists(os.path.join(current, ".git")):
        parent = os.path.dirname(current)
        if parent == current:
            return None
        current = parent
    return current


def analyzable(paths):
    found = []
    for path in paths:
        absolute = os.path.realpath(path)
        if os.path.isfile(absolute) and spec_for(absolute) is not None:
            found.append((path, absolute))
    return found


def group_by_root(items):
    roots = {}
    outside = []
    known = {}
    for path, absolute in items:
        folder = os.path.dirname(absolute)
        if folder not in known:
            known[folder] = find_root(folder)
        root = known[folder]
        if root is None:
            outside.append((path, absolute))
        else:
            roots.setdefault(root, []).append(os.path.relpath(absolute, root))
    return roots, outside


def listed(root, args, stdin=None):
    _, out = git(root, *args, stdin=stdin)
    return {path for path in out.split("\0") if path}


def tracked_among(root, paths):
    return listed(root, ["ls-files", "-z", "--", *paths])


def ignored_among(root, paths):
    return listed(root, ["--no-literal-pathspecs", "check-ignore", "-z", "--stdin"], "\0".join(paths) + "\0")


def changes_for(root, tracked):
    if not tracked:
        return {}
    return diff_changes(root, [base_ref(root), "--", *sorted(tracked)])


def without_ignored(root, paths):
    hidden = ignored_among(root, paths)
    return [path for path in paths if path not in hidden]


def root_targets(location, options):
    root, paths = location
    tracked = set() if options.all_lines else tracked_among(root, paths)
    if options.skip_ignored:
        paths = without_ignored(root, paths)
    changes = changes_for(root, tracked)
    targets = []
    for path in paths:
        change = changes.get(path, FileChange(set())) if path in tracked else everything()
        targets.append(Target(path, read_worktree(root, path), change))
    return targets


def file_targets(paths, options=FileOptions()):
    roots, outside = group_by_root(analyzable(paths))
    found = []
    for location in roots.items():
        found.extend(root_targets(location, options))
    if not options.require_repo:
        found.extend(Target(path, read_worktree("/", absolute), everything()) for path, absolute in outside)
    return [target for target in found if target.text is not None]
