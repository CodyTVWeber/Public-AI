#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: evidence-check.sh [FILE...] [--before FILE --after FILE] [--min-bytes N]
Reports size, PNG dimensions and sha256 per file as JSON on stdout.
Problems (exit 1): missing file, zero bytes, under --min-bytes (default 3000, likely blank),
before and after byte-identical. Blank frames and wrong content still need eyes.
Exit: 0 ok, 1 problems found, 2 usage.
USAGE
}

min_bytes=3000
before=""
after=""
files=()

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --before) [ $# -ge 2 ] || { usage >&2; exit 2; }; before="$2"; shift 2 ;;
    --after) [ $# -ge 2 ] || { usage >&2; exit 2; }; after="$2"; shift 2 ;;
    --min-bytes) [ $# -ge 2 ] || { usage >&2; exit 2; }; min_bytes="$2"; shift 2 ;;
    -*) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *) files+=("$1"); shift ;;
  esac
done

case "$min_bytes" in ''|*[!0-9]*) echo "--min-bytes needs an integer" >&2; exit 2 ;; esac
if [ -n "$before" ] || [ -n "$after" ]; then
  if [ -z "$before" ] || [ -z "$after" ]; then
    echo "--before and --after go together" >&2
    exit 2
  fi
  files+=("$before" "$after")
fi
[ ${#files[@]} -gt 0 ] || { usage >&2; exit 2; }

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

png_dims() {
  node -e '
const { openSync, readSync, closeSync } = require("node:fs");
const head = Buffer.alloc(24);
const fd = openSync(process.argv[1], "r");
const n = readSync(fd, head, 0, 24, 0);
closeSync(fd);
const ok = n >= 24 && head.subarray(0, 8).equals(Buffer.from("89504e470d0a1a0a", "hex")) && head.toString("latin1", 12, 16) === "IHDR";
console.log(ok ? `${head.readUInt32BE(16)} ${head.readUInt32BE(20)}` : "0 0");
' "$1"
}

entries="[]"
problems="[]"
seen=""

add_problem() {
  problems=$(jq -c --arg f "$1" --arg p "$2" '. + [{file: $f, problem: $p}]' <<<"$problems")
}

for f in "${files[@]}"; do
  case "$seen" in *"|$f|"*) continue ;; esac
  seen="$seen|$f|"
  if [ ! -f "$f" ]; then
    add_problem "$f" "missing"
    entries=$(jq -c --arg f "$f" '. + [{file: $f, exists: false}]' <<<"$entries")
    continue
  fi
  bytes=$(wc -c <"$f" | tr -d ' ')
  sha=$(sha_of "$f")
  w=null
  h=null
  case "$bytes:$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')" in
    0:*) ;;
    *:*.png)
      read -r pw ph < <(png_dims "$f")
      if [ "$pw" = 0 ]; then add_problem "$f" "not a valid png"; else w=$pw; h=$ph; fi ;;
  esac
  [ "$bytes" -eq 0 ] && add_problem "$f" "zero bytes"
  [ "$bytes" -gt 0 ] && [ "$bytes" -lt "$min_bytes" ] && add_problem "$f" "under $min_bytes bytes, likely blank"
  entries=$(jq -c --arg f "$f" --argjson b "$bytes" --arg s "$sha" --argjson w "$w" --argjson h "$h" \
    '. + [{file: $f, exists: true, bytes: $b, sha256: $s, width: $w, height: $h}]' <<<"$entries")
done

pair=null
if [ -n "$before" ] && [ -f "$before" ] && [ -f "$after" ]; then
  identical=false
  [ "$(sha_of "$before")" = "$(sha_of "$after")" ] && identical=true
  [ "$identical" = true ] && add_problem "$after" "identical to before"
  pair=$(jq -nc --arg b "$before" --arg a "$after" --argjson i "$identical" '{before: $b, after: $a, identical: $i}')
fi

ok=true
[ "$problems" != "[]" ] && ok=false
jq -nc --argjson ok "$ok" --argjson files "$entries" --argjson pair "$pair" --argjson problems "$problems" \
  '{ok: $ok, files: $files, pair: $pair, problems: $problems}'
[ "$ok" = true ]
