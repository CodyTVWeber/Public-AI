import os
import subprocess

LEGACY_ENTRIES = {"skills": (".claude/skills/",)}


def exclude_file(root):
    out = subprocess.run(["git", "-C", root, "rev-parse", "--git-path", "info/exclude"], capture_output=True, text=True)
    path = out.stdout.strip()
    return path if path.startswith("/") else os.path.join(root, path)


def markers(tag):
    return "# ai-guardrails:" + tag + ":begin", "# ai-guardrails:" + tag + ":end"


def read(path):
    try:
        with open(path) as handle:
            return handle.read()
    except OSError:
        return ""


def find_block(lines, tag):
    begin, end = markers(tag)
    if begin not in lines or end not in lines:
        return None
    return lines.index(begin), lines.index(end)


def block_entries(root, tag):
    lines = read(exclude_file(root)).split("\n")
    span = find_block(lines, tag)
    return lines[span[0] + 1:span[1]] if span else []


def render(text, tag, entries):
    lines = text.split("\n")
    span = find_block(lines, tag)
    legacy = LEGACY_ENTRIES.get(tag, ())
    block = [markers(tag)[0]] + sorted(set(entries)) + [markers(tag)[1]] if entries else []
    if span:
        lines = lines[:span[0]] + block + lines[span[1] + 1:]
    elif block:
        lines = text.rstrip("\n").split("\n") + block if text.strip() else block
    lines = [line for line in lines if line not in legacy]
    body = "\n".join(lines).rstrip("\n")
    return text if body == text.rstrip("\n") else (body + "\n" if body else "")


def block_needed(root, tag, entries):
    text = read(exclude_file(root))
    return render(text, tag, entries) != text


def write_block(root, tag, entries):
    path = exclude_file(root)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = read(path)
    updated = render(text, tag, entries)
    if updated != text:
        with open(path, "w") as handle:
            handle.write(updated)
