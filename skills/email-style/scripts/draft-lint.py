#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys

DESCRIPTION = """Lint an email draft or agent output against the email-style rules.

Profiles: email (headers, greeting, opening length, closing, signature, phone plus the shared
checks) or output (banned phrases, emoji, time-zone labels, opening length only).
Stdout: JSON list of {"line", "rule"}. Exit: 0 clean, 1 violations, 2 usage.
Greeting, closings, signature and phone come from a config JSON, never from this repo:
  --config PATH, else $AI_SKILLS_EMAIL_CONFIG, else ~/.config/ai-skills/email-style.json
  keys: "greeting" (required greeting word), "closings" (accepted closing lines),
        "signature" (name line expected after the closing), "phone" (digits compared)
Without a config the greeting, closing, signature and phone checks are skipped with a warning on stderr.
--skip RULE[,RULE] drops rules by prefix (for example header,phone,tz).
--recipient-elsewhere allows time-zone labels."""

DEFAULT_CONFIG_PATH = "~/.config/ai-skills/email-style.json"
HEADER_SCAN_LINES = 10
CLOSING_SCAN_LINES = 5
MAX_OPENING_SENTENCES = 2
GREETING_SHAPE = re.compile(r"^\S+(?:\s+\S+){0,5},\s*$")

BANNED = [
    r"hope you(?:'|’)?re (?:doing )?well",
    r"hope this (?:email|message) finds you",
    r"thanks so much",
    r"please don(?:'|’)?t hesitate",
    r"as outlined above",
    r"as (?:\w+ly )?discussed in our (?:\w+ )?correspondence",
    r"as \w+ly discussed",
    r"pursuant",
    r"aforementioned",
    r"\bleverage\b",
    r"ensure alignment",
    r"i went back and reviewed",
]
TZ = re.compile(
    r"\b\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?\s*(?:CDT|CST|CT|Central|EDT|EST|ET|Eastern|MDT|MST|MT|Mountain|PDT|PST|PT|Pacific)\b",
    re.I,
)
EMOJI = re.compile("[\U0001F000-\U0001FAFF☀-➿⭐⭕️]")
OUTLINE = re.compile(r"^\s*1\.\s")
HEADER = re.compile(r"^\*\*([A-Za-z]+):\*\*")


def load_config(path):
    path = path or os.environ.get("AI_SKILLS_EMAIL_CONFIG") or os.path.expanduser(DEFAULT_CONFIG_PATH)
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def sentence_count(text):
    return len([s for s in re.split(r"(?<=[.!?])\s+", text.strip()) if re.search(r"\w", s)])


def prose_lines(lines):
    in_fence = False
    kept = []
    for n, raw in enumerate(lines, 1):
        if raw.lstrip().startswith("```"):
            in_fence = not in_fence
        elif not in_fence:
            kept.append((n, raw))
    return kept


def style_violations(prose, tz_ok):
    out = []
    for n, raw in prose:
        if any(re.search(pat, raw.lower()) for pat in BANNED):
            out.append({"line": n, "rule": "banned_phrase"})
        if EMOJI.search(raw):
            out.append({"line": n, "rule": "emoji"})
        if not tz_ok and TZ.search(raw):
            out.append({"line": n, "rule": "tz_label"})
    return out


def header_violations(body):
    seen = {m.group(1).lower() for _, r in body[:HEADER_SCAN_LINES] if (m := HEADER.match(r))}
    return [{"line": 1, "rule": f"header_missing:{field}"} for field in ("to", "subject") if field not in seen]


def skip_headers(body):
    start = 0
    while start < len(body) and HEADER.match(body[start][1]):
        start += 1
    return start


def is_greeting(text, greeting):
    if greeting:
        return re.match(rf"^{re.escape(greeting)}\s+\S.*,\s*$", text) is not None
    return GREETING_SHAPE.match(text) is not None


def greeting_violations(body, start, greeting):
    if not greeting or (start < len(body) and is_greeting(body[start][1].strip(), greeting)):
        return []
    return [{"line": body[start][0] if start < len(body) else 1, "rule": "greeting_mismatch"}]


def opening_violations(body, start):
    outline_idx = next((i for i in range(start, len(body)) if OUTLINE.match(body[i][1])), None)
    if outline_idx is None or outline_idx == start:
        return []
    opening = " ".join(r.strip() for _, r in body[start:outline_idx])
    if sentence_count(opening) > MAX_OPENING_SENTENCES:
        return [{"line": body[start][0], "rule": "opening_over_2_sentences"}]
    return []


def closing_violations(body, config):
    tail = body[-CLOSING_SCAN_LINES:]
    closings = config.get("closings") or []
    after_from, at = 0, tail[-1][0] if tail else 1
    if closings:
        close_at = next((i for i, (_, r) in enumerate(tail) if r.strip() in closings), None)
        if close_at is None:
            return [{"line": at, "rule": "closing_missing"}]
        after_from, at = close_at + 1, tail[close_at][0]
    after = " ".join(r for _, r in tail[after_from:])
    out = []
    signature = config.get("signature")
    phone = re.sub(r"\D", "", str(config.get("phone", "")))
    if signature and signature not in after:
        out.append({"line": at, "rule": "signature_missing"})
    if phone and phone not in re.sub(r"\D", "", after):
        out.append({"line": at, "rule": "phone_missing"})
    return out


def email_violations(body, config):
    out = header_violations(body)
    start = skip_headers(body)
    greeting = (config or {}).get("greeting")
    out += greeting_violations(body, start, greeting)
    if start < len(body) and is_greeting(body[start][1].strip(), greeting):
        start += 1
    out += opening_violations(body, start)
    if config is None:
        sys.stderr.write("warning: no config, greeting, closing, signature and phone checks skipped\n")
    else:
        out += closing_violations(body, config)
    return out


def lint(lines, profile, settings):
    config, tz_ok = settings
    prose = prose_lines(lines)
    out = style_violations(prose, tz_ok)
    body = [(n, r) for n, r in prose if r.strip()]
    if profile == "email":
        return out + email_violations(body, config)
    return out + opening_violations(body, 0)


def read_lines(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().splitlines()
    except OSError:
        sys.stderr.write(f"cannot read: {path}\n")
        sys.exit(2)


def main():
    parser = argparse.ArgumentParser(prog="draft-lint.py", description=DESCRIPTION, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file")
    parser.add_argument("--profile", choices=["email", "output"], default="email")
    parser.add_argument("--config")
    parser.add_argument("--skip", default="")
    parser.add_argument("--recipient-elsewhere", action="store_true")
    args = parser.parse_args()

    lines = read_lines(args.file)
    config = load_config(args.config) if args.profile == "email" else None
    skips = [s for s in args.skip.split(",") if s]
    found = [v for v in lint(lines, args.profile, (config, args.recipient_elsewhere)) if not any(v["rule"].startswith(s) for s in skips)]
    print(json.dumps(found))
    for v in found:
        sys.stderr.write(f"line {v['line']}: {v['rule']}\n")
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main()
