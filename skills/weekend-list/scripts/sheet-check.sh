#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: sheet-check.sh FILE.pdf [--max-pages N]
Checks a printable sheet: US Letter page size, at most N pages (default 2), no URLs in the text.
Uses pdfinfo and pdftotext when present. Without pdfinfo a python3 scan of the file is tried;
anything that cannot be determined is skipped with a warning, never failed.
Stdout: {"ok", "pages", "size", "urls", "skipped": [...], "failures": [...]}.
Exit: 0 ok, 1 check failed, 2 usage.
USAGE
}

max_pages=2
file=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --max-pages) [ $# -ge 2 ] || { usage >&2; exit 2; }; max_pages="$2"; shift 2 ;;
    -*) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *) [ -z "$file" ] || { usage >&2; exit 2; }; file="$1"; shift ;;
  esac
done
[ -n "$file" ] && [ -f "$file" ] || { usage >&2; exit 2; }
case "$max_pages" in ''|*[!0-9]*) echo "--max-pages needs an integer" >&2; exit 2 ;; esac

pages=""
size=""
skipped=()
failures=()
urls="[]"

if command -v pdfinfo >/dev/null 2>&1; then
  info=$(pdfinfo "$file" 2>/dev/null || true)
  pages=$(printf '%s\n' "$info" | awk -F': *' '/^Pages:/ {print $2}')
  size=$(printf '%s\n' "$info" | awk -F': *' '/^Page size:/ {print $2}')
else
  fallback=$(python3 -I - "$file" <<'PY' || true
import re
import sys

data = open(sys.argv[1], "rb").read()
pages = len(re.findall(rb"/Type\s*/Page(?![s\w])", data))
box = re.search(rb"/MediaBox\s*\[\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\]", data)
size = ""
if box:
    w, h = float(box.group(3)) - float(box.group(1)), float(box.group(4)) - float(box.group(2))
    size = f"{w:g} x {h:g} pts"
print(f"{pages or ''}|{size}")
PY
)
  pages="${fallback%%|*}"
  size="${fallback#*|}"
  echo "warning: pdfinfo not found, used a best-effort scan" >&2
  [ -n "$pages" ] || skipped+=("pages")
  [ -n "$size" ] || skipped+=("size")
fi

if [ -n "$pages" ] && [ "$pages" -gt "$max_pages" ]; then
  failures+=("pages: $pages over $max_pages")
fi

if [ -n "$size" ]; then
  if ! printf '%s' "$size" | grep -Eiq '(612|8\.5) *(x|×) *(792|11)|(792|11) *(x|×) *(612|8\.5)|letter'; then
    failures+=("size: not US Letter")
  fi
fi

if command -v pdftotext >/dev/null 2>&1; then
  hits=$(pdftotext "$file" - 2>/dev/null | grep -Eio '(https?://|www\.)[^[:space:]]+' || true)
  if [ -n "$hits" ]; then
    urls=$(printf '%s\n' "$hits" | jq -R . | jq -sc .)
    failures+=("urls: found in text")
  fi
else
  echo "warning: pdftotext not found, URL check skipped" >&2
  skipped+=("urls")
fi

join() { if [ $# -eq 0 ]; then echo '[]'; else printf '%s\n' "$@" | jq -R . | jq -sc .; fi; }
ok=true
[ ${#failures[@]} -eq 0 ] || ok=false
jq -nc --argjson ok "$ok" --arg pages "$pages" --arg size "$size" --argjson urls "$urls" \
  --argjson skipped "$(join ${skipped[@]+"${skipped[@]}"})" --argjson failures "$(join ${failures[@]+"${failures[@]}"})" \
  '{ok: $ok, pages: ($pages | tonumber? // null), size: (if $size == "" then null else $size end), urls: $urls, skipped: $skipped, failures: $failures}'
[ "$ok" = true ] || exit 1
