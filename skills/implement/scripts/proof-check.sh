#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: proof-check.sh PR_BODY_FILE SCOPE_JSON_FILE
Checks the deterministic rows of the proof check against a PR/MR description.
Scope JSON (diff-scope.sh output; extra keys ignored), booleans, absent = false: docs_only, ui_changed, backend_changed, db_changed,
test_only. Optional: behavior_changed (needs a video), deep_change (needs a mermaid diagram).
Checks: headings Build, Proof, Try it, Review guide; Build command and CI link; Proof rows;
numbered Try it steps; Review guide labels; tier, merge policy, rollback for high tier;
image/video/curl/http/sql/mermaid counts vs scope; leftover template text.
docs_only or test_only alone needs only Build, Review guide and a "no behavior change" line.
Whether media is blank or wrong stays a human judgment.
Stdout: {"ok", "missing": [...], "counts": {...}}. Exit: 0 ok, 1 something missing, 2 usage.
USAGE
}

case "${1:-}" in -h|--help) usage; exit 0 ;; esac
[ $# -eq 2 ] || { usage >&2; exit 2; }
[ -f "$1" ] || { echo "no such file: $1" >&2; exit 2; }
[ -f "$2" ] || { echo "no such file: $2" >&2; exit 2; }
jq -e 'type == "object"' "$2" >/dev/null 2>&1 || { echo "scope is not a JSON object: $2" >&2; exit 2; }

python3 -I - "$1" "$2" <<'PY'
import json
import re
import sys

body = open(sys.argv[1], encoding="utf-8").read()
scope = json.load(open(sys.argv[2], encoding="utf-8"))
flag = lambda k: bool(scope.get(k))

blocks = []
sections = {}
current = None
fence = None
for line in body.splitlines():
    m = re.match(r"^\s*(`{3,}|~{3,})\s*(\S*)", line)
    if m and fence is None:
        fence = [m.group(2).lower(), []]
        continue
    if m and fence is not None and m.group(1)[0] in "`~" and not m.group(2):
        blocks.append((fence[0], "\n".join(fence[1])))
        fence = None
        continue
    if fence is not None:
        fence[1].append(line)
        continue
    h = re.match(r"^#{1,6}\s*(.+?)\s*#*\s*$", line)
    if h:
        current = h.group(1).lower()
        sections.setdefault(current, [])
        continue
    if current is not None:
        sections[current].append(line)

prose = re.sub(r"^\s*(`{3,}|~{3,}).*?^\s*\1\s*$", "", body, flags=re.S | re.M)


def section(name):
    for key, lines in sections.items():
        if key == name or key.startswith(name):
            return "\n".join(lines)
    return None


VIDEO = r"\.(mp4|webm|mov)(\)|\?|\s|\"|$)"
media_md = re.findall(r"!?\[[^\]]*\]\(([^)\s]+)[^)]*\)", prose)
imgs = len(re.findall(r"<img\b", prose, re.I)) + sum(
    1 for u in re.findall(r"!\[[^\]]*\]\(([^)\s]+)", prose) if not re.search(VIDEO, u + ")", re.I)
)
vids = len(re.findall(r"<video\b", prose, re.I)) + sum(
    1 for u in media_md if re.search(VIDEO, u + ")", re.I)
)
curls = sum(1 for lang, t in blocks if re.search(r"(^|\s|\$)curl\s", t))
https = sum(1 for lang, t in blocks if lang in ("http", "rest") or re.match(r"\s*(GET|POST|PUT|PATCH|DELETE)\s+\S+\s+HTTP/", t))
sqls = [t for lang, t in blocks if lang == "sql"]
merm = sum(1 for lang, _ in blocks if lang == "mermaid")
curl_needs_file = any(
    re.search(r"\s(-d|--data\S*|-H|--header|-F|--form)\s", t) for lang, t in blocks if re.search(r"curl\s", t)
)

missing = []
add = missing.append

if section("build") is None:
    add("heading:Build")
else:
    b = section("build")
    if not re.search(r"`[^`]+`", b):
        add("build:command")
    if not re.search(r"https?://", b):
        add("build:ci_link")
if section("review guide") is None:
    add("heading:Review guide")
else:
    g = section("review guide")
    for label, rx in (
        ("start_file", r"start here"),
        ("look_hard", r"look hard"),
        ("out_of_scope", r"not in this change|out of scope|not here"),
    ):
        if not re.search(rx, g, re.I):
            add(f"review_guide:{label}")

risk = section("risk")
tier = None
if risk is not None:
    t = re.search(r"\b(low|medium|high)\b", risk, re.I)
    tier = t.group(1).lower() if t else None
if tier is None:
    add("risk:tier")
if not re.search(r"merge policy", prose, re.I):
    add("risk:merge_policy")
if tier == "high" and section("rollback") is None:
    add("risk:rollback")

media_scope = any(flag(k) for k in ("ui_changed", "backend_changed", "db_changed"))
light = (flag("docs_only") or flag("test_only")) and not media_scope
if light:
    if not re.search(r"no behaviou?r change", prose, re.I):
        add("build:no_behavior_change_line")
else:
    p = section("proof")
    if p is None:
        add("heading:Proof")
    else:
        rows = [r for r in p.splitlines() if r.strip().startswith("|") and not re.match(r"^\s*\|[\s:|-]+\|?\s*$", r)]
        if len(rows) < 2:
            add("proof:row")
    ti = section("try it")
    if ti is None:
        add("heading:Try it")
    elif not re.search(r"^\s*\d+\.\s+\S", ti, re.M):
        add("try_it:numbered_steps")
    if flag("ui_changed") and imgs < 2:
        add("proof:before_after_images")
    if (flag("behavior_changed")) and vids < 1:
        add("proof:video")
    if flag("backend_changed"):
        if curls < 1:
            add("proof:curl")
        elif curl_needs_file and https < 1:
            add("proof:http_file")
    if flag("db_changed"):
        if not sqls:
            add("proof:query")
        elif any(re.search(r"\b(insert|update|delete|drop|alter|truncate|create|grant)\b", re.sub(r"--.*", "", q), re.I) for q in sqls):
            add("proof:query_not_read_only")
    if flag("deep_change") and merm < 1:
        add("proof:mermaid")

if re.search(r"`<[^`>\n]+>`|replace with the real call", body):
    add("template:placeholder_left")

counts = {"image": imgs, "video": vids, "curl": curls, "http": https, "sql": len(sqls), "mermaid": merm}
print(json.dumps({"ok": not missing, "missing": missing, "counts": counts}))
for m in missing:
    sys.stderr.write(f"missing: {m}\n")
sys.exit(1 if missing else 0)
PY
