#!/usr/bin/env bash
# Cheap mechanical clean-code checks on staged files. Nesting, params and function length are the
# linters' job (see assets/lint); this covers what linters usually miss.
#
# Usage: check-clean-code.sh [files...]   (default: staged files)
# Env:   FILE_SOFT (default 200) warn; FILE_HARD (default 400) fail when a file at or over it grows;
#        CLEAN_CODE_SKIP=1 skips.
# Exit:  0 ok, 1 violations.
#
# Checks: file size (only when the change makes a large file bigger), empty catch blocks.

set -uo pipefail

SOFT="${FILE_SOFT:-200}"
HARD="${FILE_HARD:-400}"
CODE_EXT='\.(ts|tsx|js|jsx|mjs|kt|java|py|go|rb|rs|swift|cs|php|scala)$'

[ "${CLEAN_CODE_SKIP:-0}" = "1" ] && { echo "clean-code: skipped (CLEAN_CODE_SKIP=1)"; exit 0; }

if [ "$#" -gt 0 ]; then
  files=("$@"); diff_cmd=(git diff HEAD --)
else
  files=(); while IFS= read -r f; do files+=("$f"); done < <(git diff --cached --name-only --diff-filter=ACMR)
  diff_cmd=(git diff --cached --)
fi

failed=0
for f in "${files[@]}"; do
  [[ "$f" =~ $CODE_EXT ]] || continue
  [[ "$f" == *test* || "$f" == *generated* || "$f" == *.d.ts ]] && continue
  [ -f "$f" ] || continue

  lines=$(wc -l < "$f" | tr -d ' ')
  added=$("${diff_cmd[@]}" "$f" | grep -c '^+[^+]' || true)
  removed=$("${diff_cmd[@]}" "$f" | grep -c '^-[^-]' || true)

  if [ "$lines" -ge "$HARD" ] && [ "$added" -gt "$removed" ]; then
    echo "[file size] $f is $lines lines and this change grows it (hard stop $HARD): extract first"
    failed=1
  elif [ "$lines" -gt "$SOFT" ] && [ "$added" -gt "$removed" ]; then
    echo "[file size] warn: $f is $lines lines (target <= $SOFT); prefer extracting what you add"
  fi

  if "${diff_cmd[@]}" "$f" | grep -E '^\+' | grep -Eq 'catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}|except[^:]*:[[:space:]]*pass[[:space:]]*$'; then
    echo "[empty catch] $f adds an empty catch/except: call a named ignore helper instead"
    failed=1
  fi
done

[ "$failed" -ne 0 ] && echo "clean-code: BLOCKED (see .claude/rules/clean-code.md; one-off override: CLEAN_CODE_SKIP=1)"
exit "$failed"
