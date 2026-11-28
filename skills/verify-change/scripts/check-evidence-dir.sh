#!/usr/bin/env bash
set -euo pipefail

MAX_BYTES=32768
KIND_OK="image video curl query log diagram script build"

usage() {
  cat <<'EOF'
Usage: check-evidence-dir.sh DIR [--allow-pending]
Checks the plan sibling folder: kinds.json, evidence.md, no binaries, each file
≤ 32768 bytes. kinds includes script → a .sh; query → a .sql or .sh.
Empty kinds[] (no product evidence) is valid and needs no script.
Stdout: {"ok","missing":[],"kinds":[],"files":[]}. Exit: 0 ok, 1 missing, 2 usage.
EOF
}

allow_pending=false
dir=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --allow-pending) allow_pending=true; shift ;;
    -*) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *) [ -z "$dir" ] || { usage >&2; exit 2; }; dir="$1"; shift ;;
  esac
done
[ -n "$dir" ] || { usage >&2; exit 2; }
[ -d "$dir" ] || { echo "no such directory: $dir" >&2; exit 2; }
dir="$(cd "$dir" && pwd)"

check_kinds_file() {
  local kinds k
  [ -f "$dir/kinds.json" ] || { add "kinds.json: missing"; return 0; }
  jq -e 'type == "object" and (.kinds | type == "array") and (.reason | type == "string" and length > 0)' \
    "$dir/kinds.json" >/dev/null 2>&1 || { add "kinds.json: need {kinds[], reason}"; return 0; }
  kinds_json=$(jq -c '.kinds' "$dir/kinds.json")
  kinds=$(jq -r '.kinds[]' "$dir/kinds.json")
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    kind_ok "$k" || add "kinds.json: unknown kind $k"
  done <<<"$kinds"
}

check_evidence_md() {
  local body
  [ -f "$dir/evidence.md" ] || { add "evidence.md: missing"; return 0; }
  body=$(cat "$dir/evidence.md")
  printf '%s\n' "$body" | awk 'NR<=10 && /^Date: [0-9]{4}-[0-9]{2}-[0-9]{2}/ { found=1 } END { exit found ? 0 : 1 }' \
    || add "evidence.md: Date: YYYY-MM-DD in first 10 lines"
  printf '%s\n' "$body" | grep -Eq '^## Proof' || add "evidence.md: ## Proof"
  if printf '%s\n' "$body" | grep -Eq 'https?://'; then
    :
  elif [ "$allow_pending" = true ] && printf '%s\n' "$body" | grep -Eq '^PR: pending'; then
    :
  else
    add "evidence.md: PR URL (or PR: pending with --allow-pending)"
  fi
  if printf '%s\n' "$body" | grep -Fq '{{'; then add "evidence.md: leftover {{placeholder}}"; fi
}

check_kind_files() {
  local kinds="$1"
  case ",$(jq -r 'join(",")' <<<"$kinds")," in
    *,script,*) has_ext sh || add "script: need a .sh in the folder" ;;
  esac
  case ",$(jq -r 'join(",")' <<<"$kinds")," in
    *,query,*)
      has_ext sql || has_ext sh || add "query: need a .sql or a .sh"
      ;;
  esac
}

scan_files() {
  local f rel bytes
  while IFS= read -r -d '' f; do
    rel="${f#"$dir"/}"
    bytes=$(wc -c <"$f" | tr -d ' ')
    is_bin "$rel" && add "binary: $rel"
    [ "$bytes" -le "$MAX_BYTES" ] || add "over ${MAX_BYTES}B: $rel"
    files_json=$(jq -c --arg p "$rel" --argjson b "$bytes" '. + [{path:$p,bytes:$b}]' <<<"$files_json")
  done < <(find "$dir" -type f ! -path '*/.*' -print0 | sort -z)
}

has_ext() { find "$dir" -type f -name "*.$1" ! -path '*/.*' | grep -q .; }
is_bin() { case "${1##*.}" in png|jpg|jpeg|gif|webp|pdf|zip|gz|ico|mov|mp4) return 0 ;; esac; return 1; }
kind_ok() { case " $KIND_OK " in *" $1 "*) return 0 ;; esac; return 1; }
add() { missing=$(jq -c --arg m "$1" '. + [$m]' <<<"$missing"); }

missing="[]"
kinds_json="[]"
files_json="[]"
check_kinds_file
check_evidence_md
[ "$kinds_json" != "[]" ] && check_kind_files "$kinds_json"
scan_files
ok=true
[ "$missing" = "[]" ] || ok=false
jq -nc --argjson ok "$ok" --argjson missing "$missing" --argjson kinds "$kinds_json" --argjson files "$files_json" \
  '{ok:$ok,missing:$missing,kinds:$kinds,files:$files}'
[ "$ok" = true ]
