import os
import re
import subprocess
from dataclasses import dataclass

EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
HUNK = re.compile(r"^@@ -\d+(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
NEW_FILE_MARK = "--- /dev/null"
TARGET_PREFIX = "+++ b/"
DIFF_FLAGS = ("-c", "core.quotepath=off", "diff", "-U0", "--no-color", "--no-ext-diff",
              "-M", "--diff-filter=ACMR", "--src-prefix=a/", "--dst-prefix=b/")


GIT_ENV = {**os.environ, "GIT_LITERAL_PATHSPECS": "1"}


class GitError(Exception):
    pass


@dataclass
class FileChange:
    lines: object
    added: int = 0
    removed: int = 0
    is_new: bool = False

    def has(self, line):
        return self.lines is None or line in self.lines

    def touches(self, low, high):
        if self.lines is None:
            return True
        return any(low <= line <= high for line in self.lines)

    @property
    def grows(self):
        return self.is_new or self.added > self.removed


def everything():
    return FileChange(None, 0, 0, True)


def git(cwd, *args, stdin=None):
    done = subprocess.run(["git", "-C", cwd, *args], input=stdin, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, errors="replace", env=GIT_ENV)
    return done.returncode, done.stdout


def toplevel(cwd):
    code, out = git(cwd, "rev-parse", "--show-toplevel")
    return out.strip() if code == 0 else None


def require_root(cwd):
    root = toplevel(cwd)
    if root is None:
        raise GitError("not inside a git work tree: " + cwd)
    return root


def base_ref(root):
    code, _ = git(root, "rev-parse", "--verify", "-q", "HEAD")
    return "HEAD" if code == 0 else EMPTY_TREE


def parse_diff(text):
    changes = {}
    current = None
    new_file = False
    in_hunk = False
    for line in text.split("\n"):
        if line.startswith("diff --git "):
            current, new_file, in_hunk = None, False, False
        elif in_hunk and not line.startswith("@@"):
            continue
        elif line == NEW_FILE_MARK:
            new_file = True
        elif line.startswith(TARGET_PREFIX):
            current = line[len(TARGET_PREFIX):].split("\t")[0]
            changes[current] = FileChange(set(), is_new=new_file)
        elif current and line.startswith("@@"):
            in_hunk = True
            add_hunk(changes[current], line)
    return changes


def add_hunk(change, header):
    found = HUNK.match(header)
    if not found:
        return
    removed = int(found.group(1) or 1)
    start = int(found.group(2))
    count = 1 if found.group(3) is None else int(found.group(3))
    change.lines.update(range(start, start + count))
    change.added += count
    change.removed += removed


def diff_changes(root, extra):
    code, out = git(root, *DIFF_FLAGS, *extra)
    if code != 0:
        raise GitError("git diff failed: " + " ".join(extra))
    return parse_diff(out)
