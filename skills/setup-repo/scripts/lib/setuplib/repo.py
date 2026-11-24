import fnmatch
import json
import os
import subprocess

SKIP_DIRS = {".git", "node_modules", "vendor", "dist", "build", "target", ".venv", "venv", "__pycache__",
             ".gradle", ".idea", ".next", "coverage"}
GIT_TIMEOUT_SECONDS = 20
MAX_READ_BYTES = 2_000_000


def run_git(root, args):
    try:
        result = subprocess.run(["git", "-C", root] + args, capture_output=True, text=True,
                                timeout=GIT_TIMEOUT_SECONDS)
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout if result.returncode == 0 else None


def walk_files(root):
    found = []
    for base, dirs, names in os.walk(root):
        dirs[:] = [name for name in dirs if name not in SKIP_DIRS]
        rel_base = os.path.relpath(base, root)
        found.extend(name if rel_base == "." else os.path.join(rel_base, name) for name in names)
    return sorted(found)


class Repo:
    def __init__(self, root):
        self.root = os.path.realpath(root)
        listing = run_git(self.root, ["ls-files", "-z", "-co", "--exclude-standard"])
        self.is_git = run_git(self.root, ["rev-parse", "--is-inside-work-tree"]) is not None
        names = listing.split("\0") if listing else walk_files(self.root)
        self.files = sorted(name for name in names if name and os.path.lexists(self.path(name)))

    def path(self, rel):
        return os.path.join(self.root, rel)

    def has(self, rel):
        return os.path.lexists(self.path(rel))

    def read(self, rel):
        try:
            with open(self.path(rel), errors="replace") as handle:
                return handle.read(MAX_READ_BYTES)
        except OSError:
            return ""

    def json(self, rel):
        try:
            return json.loads(self.read(rel))
        except ValueError:
            return {}

    def match(self, pattern):
        return [name for name in self.files if fnmatch.fnmatch(name, pattern)]

    def named(self, basename, max_depth=3):
        return [name for name in self.files
                if os.path.basename(name) == basename and name.count("/") < max_depth]

    def git(self, *args):
        return run_git(self.root, list(args))
