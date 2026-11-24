import re

from . import gitparse
from .tags import COMMIT_LIKE, DENY_HOOKSPATH, DENY_NO_VERIFY, PUSH_LIKE

KNOWN = set("""add am annotate apply archive backfill bisect blame branch bugreport bundle cat-file
check-attr check-ignore check-mailmap check-ref-format checkout checkout-index cherry cherry-pick
clean clone column commit commit-graph commit-tree config count-objects credential describe diagnose
diff diff-files diff-index diff-tree difftool fast-export fast-import fetch fetch-pack filter-branch
fmt-merge-msg for-each-ref for-each-repo format-patch fsck gc get-tar-commit-id grep hash-object help
hook http-fetch http-push index-pack init interpret-trailers last-modified log ls-files ls-remote
ls-tree mailinfo mailsplit maintenance merge merge-base merge-file merge-index merge-tree mergetool
mktag mktree multi-pack-index mv name-rev notes pack-objects pack-redundant pack-refs patch-id prune
prune-packed pull push range-diff read-tree rebase reflog refs remote repack replace replay
request-pull rerere reset restore rev-list rev-parse revert rm scalar send-email send-pack shortlog
show show-branch show-index show-ref sparse-checkout stash status stripspace submodule switch
symbolic-ref tag unpack-file unpack-objects update-index update-ref update-server-info var
verify-commit verify-pack verify-tag version whatchanged worktree write-tree""".split())
TRACKED = {"commit", "push", "merge", "pull"}
COMMIT_LIKE_SUBS = {"merge", "cherry-pick", "revert", "am", "commit-tree", "update-ref",
                    "filter-branch", "fast-import"}
PUSH_LIKE_SUBS = {"send-pack", "http-push"}
NO_VERIFY_SUBS = COMMIT_LIKE_SUBS | {"pull", "rebase"}
CONFIG_VALUE_OPTS = {"-f", "--file", "--blob", "--default", "--type", "--comment"}
CONFIG_READ_FLAGS = {"--get", "--get-all", "--get-regexp", "--get-urlmatch", "--list", "-l",
                     "--unset", "--unset-all", "--name-only"}
EXEC_MIN = 4
SHORT_EXEC = re.compile(r"^-[a-zA-Z]*x")


def scan(sub, rest, found):
    if sub in TRACKED:
        found.add(sub)
    if sub == "commit":
        gitparse.scan_commit(rest, found)
    if sub == "push":
        gitparse.scan_push(rest, found)
    if sub in COMMIT_LIKE_SUBS:
        found.add(COMMIT_LIKE)
    if sub in PUSH_LIKE_SUBS:
        found.add(PUSH_LIKE)
    if sub in NO_VERIFY_SUBS:
        scan_no_verify(sub, rest, found)
    if sub == "config" and config_writes_hooks_path(rest):
        found.add(DENY_HOOKSPATH)
    return embedded_commands(sub, rest, found)


def bypasses_verify(sub, arg):
    if arg.startswith("--"):
        return gitparse.abbreviation(arg.split("=", 1)[0], "--no-verify")
    return sub == "am" and arg.startswith("-") and "n" in arg


def scan_no_verify(sub, rest, found):
    args = rest[:rest.index("--")] if "--" in rest else rest
    if any(bypasses_verify(sub, arg) for arg in args):
        found.add(DENY_NO_VERIFY)


def split_config_args(rest):
    words, flags, skip = [], set(), False
    for arg in rest:
        if skip:
            skip = False
        elif arg in CONFIG_VALUE_OPTS:
            skip = True
        elif arg.startswith("-"):
            flags.add(arg.split("=", 1)[0])
        else:
            words.append(arg.lower())
    return words, flags


def config_writes_hooks_path(rest):
    words, flags = split_config_args(rest)
    if gitparse.HOOKS_KEY not in words or flags & CONFIG_READ_FLAGS:
        return False
    if "--add" in flags or "--replace-all" in flags:
        return True
    return words.index(gitparse.HOOKS_KEY) < len(words) - 1


def embedded_commands(sub, rest, found):
    if sub == "rebase":
        return exec_commands(rest, "--exec", found)
    if sub in ("difftool", "mergetool"):
        return exec_commands(rest, "--extcmd", [])
    if sub == "submodule":
        return foreach_command(rest, found)
    if sub == "bisect" and "run" in rest:
        return [gitparse.quote_all(rest[rest.index("run") + 1:])]
    return []


def exec_value(arg, following, long_name):
    name, equals, inline = arg.partition("=")
    if arg.startswith("--"):
        if not gitparse.abbreviation(name, long_name, EXEC_MIN):
            return None
        return inline if equals else (following[0] if following else "")
    if SHORT_EXEC.match(arg):
        return arg.split("x", 1)[1] or (following[0] if following else "")
    return None


def exec_commands(rest, long_name, found):
    values = [exec_value(arg, rest[pos + 1:pos + 2], long_name) for pos, arg in enumerate(rest)]
    commands = [value for value in values if value is not None]
    if commands and isinstance(found, set):
        found.add(COMMIT_LIKE)
    return commands


def foreach_command(rest, found):
    words = [arg for arg in rest if not arg.startswith("-")]
    if not words or words[0] != "foreach":
        return []
    found.add(COMMIT_LIKE)
    return [" ".join(rest[rest.index("foreach") + 1:])]
