#!/usr/bin/env bash
# Cheap mechanical clean-code checks on staged files. Nesting, params and function length are the
# linters' job (see assets/lint); this covers what linters usually miss.
#
# Usage: check-clean-code.sh [files...]   (default: staged files)
# Env:   FILE_SOFT (default 200) warn; FILE_HARD (default 400) fail when a file at or over it grows;
#        CLEAN_CODE_SKIP=1 skips.
# Exit:  0 ok, 1 violations.
#
# Checks: file size (only when the change makes a large file bigger), empty catch blocks,
# added comments (ban-comments.md).

set -uo pipefail

SOFT="${FILE_SOFT:-200}"
HARD="${FILE_HARD:-400}"
CODE_EXT='\.(ts|tsx|js|jsx|mjs|kt|java|py|go|rb|rs|swift|cs|php|scala)$'

# Print the comment body and return 0 when the line is a comment. Return 1 otherwise.
comment_body() {
  local file="$1" line="$2" body=""
  case "$file" in
    *.py|*.rb)
      [[ "$line" =~ ^[[:space:]]*#! ]] && return 1
      if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ [[:space:]]# ]]; then
        body=$(printf '%s\n' "$line" | sed -E 's/^[^#]*#[[:space:]]*//; s/[[:space:]]+$//')
      else
        return 1
      fi
      ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.kt|*.java|*.go|*.rs|*.swift|*.cs|*.php|*.scala)
      if [[ "$line" =~ ^[[:space:]]*// ]]; then
        body=$(printf '%s\n' "$line" | sed -E 's|^[[:space:]]*//[[:space:]]*||; s/[[:space:]]+$//')
      elif [[ "$line" =~ ^[[:space:]]*/\* ]]; then
        body=$(printf '%s\n' "$line" | sed -E 's|^[[:space:]]*/\*[[:space:]]*||; s|[[:space:]]*\*/[[:space:]]*$||; s/[[:space:]]+$//')
      elif [[ "$line" =~ ^[[:space:]]*\*([^[:alnum:]_]|$) ]]; then
        body=$(printf '%s\n' "$line" | sed -E 's|^[[:space:]]*\*[[:space:]]*||; s|[[:space:]]*\*/[[:space:]]*$||; s/[[:space:]]+$//')
      elif [[ "$line" =~ \{/\* ]]; then
        body=$(printf '%s\n' "$line" | sed -E 's|.*\{/\*[[:space:]]*||; s|[[:space:]]*\*/\}.*||; s/[[:space:]]+$//')
      elif [[ "$line" =~ [[:space:]]// ]]; then
        local no_url="${line//:\/\//}"
        [[ "$no_url" =~ [[:space:]]// ]] || return 1
        body=$(printf '%s\n' "$line" | sed -E 's|^.*[^:]//[[:space:]]*||; s/[[:space:]]+$//')
      else
        return 1
      fi
      ;;
    *) return 1 ;;
  esac
  printf '%s' "$body"
  return 0
}

# 0 = allowed exception, 1 = banned comment.
comment_allowed() {
  local text="$1"
  [[ "$text" =~ ^ignore([^[:alnum:]_]|$) ]] && return 1
  [[ "$text" =~ ^STATUS: ]] && return 1
  [[ "$text" =~ ^[=\-]{4,} ]] && return 1
  [[ "$text" =~ ^(security|quirk|tradeoff):[[:space:]]+[^[:space:]] ]] && return 0
  [[ "$text" =~ ^SPDX-License-Identifier: ]] && return 0
  [[ "$text" =~ ^Copyright[[:space:]] ]] && return 0
  [[ "$text" =~ eslint-disable[a-z-]*[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]] ]] && return 0
  [[ "$text" =~ @ts-expect-error[[:space:]]+[^[:space:]] ]] && return 0
  [[ "$text" =~ @ts-nocheck[[:space:]]+[^[:space:]] ]] && return 0
  [[ "$text" =~ noqa:[[:space:]]*[^[:space:]]+[[:space:]]+[^[:space:]] ]] && return 0
  [[ "$text" =~ type:[[:space:]]*ignore.*#[[:space:]]*[^[:space:]] ]] && return 0
  [[ "$text" =~ prettier-ignore[[:space:]]+[^[:space:]] ]] && return 0
  return 1
}

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

  while IFS= read -r added_line; do
    if body="$(comment_body "$f" "$added_line")"; then
      if ! comment_allowed "$body"; then
        echo "[ban comments] $f adds a comment: ${added_line:0:120}"
        echo "  name it or extract it. See ban-comments.md. Allowed: quirk:, security:, tradeoff:, a lint disable with a reason."
        failed=1
      fi
    fi
  done < <("${diff_cmd[@]}" "$f" | grep -E '^\+' | grep -Ev '^\+\+\+' | sed 's/^\+//' || true)
done

[ "$failed" -ne 0 ] && echo "clean-code: BLOCKED (see .claude/rules/clean-code.md and ban-comments.md; one-off override: CLEAN_CODE_SKIP=1)"
exit "$failed"
