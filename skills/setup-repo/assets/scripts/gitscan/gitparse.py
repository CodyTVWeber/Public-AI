import re
import shlex

from .shellsyntax import ASSIGN
from .tags import COMMIT, COMMIT_LIKE, DENY_HOOKSPATH, DENY_NO_VERIFY as NO_VERIFY, DENY_SKIP, PUSH, PUSH_LIKE, SKIP_SOFT

HOOKS_KEY = "core.hookspath"
ABBREV_MIN = 6
ALIAS_TIMEOUT_SECONDS = 3
GIT_ARG_OPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix",
                "--config-env", "--attr-source"}
COMMIT_ARGS = {"-m", "-F", "-c", "-C", "-t", "--message", "--file", "--reuse-message",
               "--reedit-message", "--template", "--author", "--date", "--cleanup", "--fixup",
               "--squash", "--trailer"}
PUSH_ARGS = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
COMMIT_VALUE_FLAGS = "mFcCt"
COMMIT_SKIP_FLAGS = "mFcCtSu"


def abbreviation(arg, full, min_len=ABBREV_MIN):
    return len(arg) >= min_len and full.startswith(arg)


def note_assign(token, found):
    match = ASSIGN.match(token)
    if not match:
        return
    name, value = match.group(1), match.group(2)
    if name == "CLEAN_CODE_SKIP" and value not in ("", "0"):
        found.add(DENY_SKIP)
    elif name == "SKIP" and value:
        found.add(SKIP_SOFT)
    elif name == "HUSKY" and value == "0":
        found.add(SKIP_SOFT)
    elif name.startswith("GIT_CONFIG_KEY_") and value.lower() == HOOKS_KEY:
        found.add(DENY_HOOKSPATH)
    elif name == "GIT_CONFIG_PARAMETERS" and "hookspath" in value.lower():
        found.add(DENY_HOOKSPATH)


def scan_short_commit_flags(arg, found):
    for pos, char in enumerate(arg[1:], 1):
        if char == "n":
            found.add(NO_VERIFY)
            return 0
        if char in COMMIT_SKIP_FLAGS:
            return 1 if char in COMMIT_VALUE_FLAGS and pos == len(arg) - 1 else 0
    return 0


def scan_commit(rest, found):
    i = 0
    while i < len(rest) and rest[i] != "--":
        arg = rest[i]
        if arg in COMMIT_ARGS:
            i += 2
            continue
        if arg.startswith("--") and abbreviation(arg, "--no-verify"):
            found.add(NO_VERIFY)
        elif not arg.startswith("--") and arg.startswith("-") and len(arg) > 1:
            i += scan_short_commit_flags(arg, found)
        i += 1


def scan_push(rest, found):
    i = 0
    while i < len(rest) and rest[i] != "--":
        arg = rest[i]
        if arg in PUSH_ARGS:
            i += 2
            continue
        if arg.startswith("--"):
            scan_long_push_flag(arg, found)
        elif arg in ("-f", "-d") or arg.startswith(("+", ":")):
            found.add("push-force")
        i += 1


def scan_long_push_flag(arg, found):
    if abbreviation(arg, "--no-verify"):
        found.add(NO_VERIFY)
    if arg.startswith("--force") or arg in ("--delete", "--mirror"):
        found.add("push-force")


def split_git_args(args):
    i, cfg = 0, []
    while i < len(args) and args[i].startswith("-"):
        if args[i] in ("-c", "--config-env") and i + 1 < len(args):
            cfg.append(args[i + 1] if args[i] == "-c" else config_env_entry(args[i + 1]))
        elif args[i].startswith("--config-env="):
            cfg.append(config_env_entry(args[i].split("=", 1)[1]))
        i += 2 if args[i] in GIT_ARG_OPTS else 1
    return i, cfg


def config_env_entry(spec):
    name, _, variable = spec.partition("=")
    return name + "=$" + variable


def hooks_override(cfg):
    return any(entry.lower().startswith(HOOKS_KEY) for entry in cfg)


def alias_from_config(name, cfg):
    for entry in cfg:
        if entry.lower().startswith("alias." + name.lower() + "="):
            return entry.split("=", 1)[1]
    return None


def alias_from_git(name, cwd):
    import subprocess
    try:
        result = subprocess.run(["git", "config", "--get", "alias." + name], cwd=cwd or None,
                                capture_output=True, text=True, timeout=ALIAS_TIMEOUT_SECONDS)
        return result.stdout.strip() or None
    except Exception:
        return None


def quote_all(words):
    return " ".join(shlex.quote(word) for word in words)


FALLBACK_WORDS = (("commit", COMMIT), ("push", PUSH), ("merge", COMMIT_LIKE), ("cherry-pick", COMMIT_LIKE),
                  ("revert", COMMIT_LIKE), ("send-pack", PUSH_LIKE), ("update-ref", COMMIT_LIKE),
                  ("commit-tree", COMMIT_LIKE))


def fallback_tags(text, found):
    for word, tag in FALLBACK_WORDS:
        if re.search(r"\bgit\b[^\n;&|]*\b" + word + r"\b", text):
            found.add(tag)


def coarse_tags(text, found):
    if not re.search(r"\bgit\b", text, re.I):
        return
    for word, tag in FALLBACK_WORDS:
        if re.search(r"\b" + word + r"\b", text):
            found.add(tag)
