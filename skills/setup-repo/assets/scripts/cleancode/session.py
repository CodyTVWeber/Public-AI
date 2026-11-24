import hashlib
import os
import re
import time

TTL_SECONDS = 7 * 24 * 3600
DEFAULT_MAX_ENTRIES = 500
PREFIX = "cc-session-"
SUFFIX = ".edited"
UNSAFE = re.compile(r"[^A-Za-z0-9_-]")


def max_entries():
    raw = os.environ.get("CC_SESSION_LOG_MAX", "")
    return int(raw) if raw.isdigit() and int(raw) > 0 else DEFAULT_MAX_ENTRIES


def log_directory():
    return os.environ.get("TMPDIR") or "/tmp"


def log_path(payload):
    name = UNSAFE.sub("_", str(payload.get("session_id") or ""))[:80]
    if not name:
        cwd = payload.get("cwd") or os.getcwd()
        name = "cwd-" + hashlib.sha1(cwd.encode()).hexdigest()[:12]
    return os.path.join(log_directory(), PREFIX + name + SUFFIX)


def parse_entries(text):
    entries = []
    for line in text.split("\n"):
        stamp, _, path = line.partition("\t")
        if stamp.isdigit() and path:
            entries.append((int(stamp), path))
    return entries


def read_entries(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return parse_entries(handle.read())
    except OSError:
        return []


def fresh(entries, now):
    return [(stamp, path) for stamp, path in entries if now - stamp <= TTL_SECONDS]


def latest_unique(entries):
    seen = set()
    kept = []
    for stamp, path in reversed(entries):
        if path not in seen:
            seen.add(path)
            kept.append((stamp, path))
    kept.reverse()
    return kept


def write_entries(path, entries):
    temporary = "%s.%d.tmp" % (path, os.getpid())
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        handle.write("".join("%d\t%s\n" % entry for entry in entries))
    os.replace(temporary, path)


def append_entry(path, entry):
    flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags, 0o600)
    with os.fdopen(descriptor, "a", encoding="utf-8") as handle:
        handle.write("%d\t%s\n" % entry)


def is_stale_log(item, now):
    named = item.name.startswith(PREFIX) and item.name.endswith(SUFFIX)
    return named and now - item.stat(follow_symlinks=False).st_mtime > TTL_SECONDS


def remove_stale_logs(directory, now):
    try:
        listing = list(os.scandir(directory))
    except OSError:
        return
    for item in listing:
        if is_stale_log(item, now):
            os.unlink(item.path)


def record(payload, edited):
    now = int(time.time())
    path = log_path(payload)
    try:
        append_entry(path, (now, edited))
        entries = read_entries(path)
        kept = latest_unique(fresh(entries, now))[-max_entries():]
        if len(kept) != len(entries):
            write_entries(path, kept)
        remove_stale_logs(log_directory(), now)
    except OSError:
        return


def logged_paths(payload):
    entries = fresh(read_entries(log_path(payload)), int(time.time()))
    return [path for _, path in latest_unique(entries) if os.path.isfile(path)]
