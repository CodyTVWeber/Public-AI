#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: lint-explainer.sh <file.html> | --hook | -h|--help

Lints an explain-code HTML explainer:
  - leftover {{TOKEN}} placeholders
  - getElementById('literal') with no matching id="literal" (or .id= / setAttribute('id'))
  - unbalanced <script> / </script> tags
Only files with explainer markers (runAnimation, FAIL_INDEX, class="item-list") are checked.
--hook  PostToolUse(Write|Edit): reads hook JSON on stdin, checks .tool_input.file_path when it
        is *.html (template files under /templates/ are skipped); failures go to stderr, exit 2
Exit: 0 ok or not an explainer, 1 check failed, 2 usage (or failure in --hook mode)
EOF
}

mode=file
file=""
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --hook) mode=hook ;;
  "") usage >&2; exit 2 ;;
  -*) usage >&2; exit 2 ;;
  *) file="$1" ;;
esac

if [ "$mode" = hook ]; then
  file="$(jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  case "$file" in
    *.html) ;;
    *) exit 0 ;;
  esac
  case "$file" in
    */templates/*) exit 0 ;;
  esac
fi

[ -f "$file" ] || { [ "$mode" = hook ] && exit 0; echo "lint-explainer: no such file: $file" >&2; exit 2; }

grep -Eq 'runAnimation|FAIL_INDEX|class="item-list"' "$file" || exit 0

problems=()

while IFS= read -r tok; do
  problems+=("leftover placeholder $tok")
done < <(grep -Eo '\{\{[A-Z][A-Z0-9_]*\}\}' "$file" | sort -u)

while IFS= read -r id; do
  [ -n "$id" ] || continue
  esc="$(printf '%s' "$id" | sed 's/[][\.*^$/]/\\&/g')"
  if ! grep -Eq "\bid[[:space:]]*=[[:space:]]*[\"']$esc[\"']|\.id[[:space:]]*=[[:space:]]*[\"']$esc[\"']|setAttribute\([[:space:]]*[\"']id[\"'],[[:space:]]*[\"']$esc[\"']" "$file"; then
    problems+=("getElementById('$id') has no matching id")
  fi
done < <(grep -Eo "getElementById\([[:space:]]*[\"'][^\"']+[\"'][[:space:]]*\)" "$file" | sed -E "s/^getElementById\([[:space:]]*[\"']//; s/[\"'][[:space:]]*\)\$//" | sort -u)

opens="$(grep -Eo '<script([[:space:]>]|$)' "$file" | wc -l | tr -d ' ' || true)"
closes="$(grep -Eo '</script[[:space:]]*>' "$file" | wc -l | tr -d ' ' || true)"
[ "$opens" -eq "$closes" ] || problems+=("unbalanced script tags: $opens opening, $closes closing")

if [ "${#problems[@]}" -gt 0 ]; then
  {
    echo "lint-explainer: $file"
    printf '  - %s\n' "${problems[@]}"
    echo "Fix the explainer (see skills/explain-code/explain-code.md, Step 4) and re-check."
  } >&2
  [ "$mode" = hook ] && exit 2
  exit 1
fi
exit 0
