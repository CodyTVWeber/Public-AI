#!/usr/bin/env bash

set -uo pipefail

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: check-clean-code.sh [files...]   (default: staged files)
Env:   FILE_SOFT (default 200) warn; FILE_HARD (default 400) fail when a file at or over it grows;
       CLEAN_CODE_SKIP=1 skips.
Checks: file size (only when the change makes a large file bigger), empty catch blocks,
        added comments in code and tests (rules/ban-comments.md). When code-quality-check.sh sits
        next to this script, staged mode also runs it: nesting, params, function length, magic
        numbers and the rest of its rules. It skips the three checks above for the languages
        this script already covers, so nothing is reported twice.
Exit:  0 ok, 1 violations.
EOF
    exit 0 ;;
esac

SOFT="${FILE_SOFT:-200}"
HARD="${FILE_HARD:-400}"
LEGACY_EXTS='ts+tsx+js+jsx+mjs+kt+java+py+go+rb+rs+swift+cs+php+scala'
CODE_EXT="\\.(${LEGACY_EXTS//+/|})\$"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
analyzer="$here/code-quality-check.sh"

is_generated_path() {
  local f="$1" base="${1##*/}"
  case "/$f" in
    */generated/*|*/__generated__/*) return 0 ;;
  esac
  case "$base" in
    *.d.ts|*.generated.*) return 0 ;;
  esac
  return 1
}

is_skipped_path() {
  local f="$1" base="${1##*/}"
  case "/$f" in
    */test/*|*/tests/*|*/__tests__/*|*/spec/*|*/specs/*|*/__mocks__/*|*/fixtures/*|*/testdata/*|*/e2e/*|*/generated/*|*/__generated__/*) return 0 ;;
  esac
  case "$base" in
    *.test.*|*.spec.*|*_test.*|*_spec.*|test_*|*Test.*|*Tests.*|*.d.ts|*.generated.*) return 0 ;;
  esac
  return 1
}

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

comment_allowed() {
  local text="$1"
  [[ "$text" =~ ^ignore([^[:alnum:]_]|$) ]] && return 1
  [[ "$text" =~ ^STATUS: ]] && return 1
  [[ "$text" =~ ^[=\-]{4,} ]] && return 1
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
for f in ${files[@]+"${files[@]}"}; do
  [[ "$f" =~ $CODE_EXT ]] || continue
  is_generated_path "$f" && continue
  [ -f "$f" ] || continue
  is_skipped_path "$f" && skip_size=1 || skip_size=0

  if [ "$skip_size" -eq 0 ]; then
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
  fi

  while IFS= read -r added_line; do
    if body="$(comment_body "$f" "$added_line")"; then
      if ! comment_allowed "$body"; then
        echo "[ban comments] $f adds a comment: ${added_line:0:120}"
        echo "  rename or extract it. See ban-comments.md. Allowed: license lines and tool directives with a reason."
        failed=1
      fi
    fi
  done < <("${diff_cmd[@]}" "$f" | grep -E '^\+' | grep -Ev '^\+\+\+' | sed 's/^\+//' || true)
done

if [ "$#" -eq 0 ] && [ -x "$analyzer" ]; then
  legacy_scope="@$LEGACY_EXTS"
  skip_legacy="added-comment$legacy_scope,empty-catch$legacy_scope,file-size$legacy_scope"
  CC_DISABLE="${CC_DISABLE:+$CC_DISABLE,}$skip_legacy" "$analyzer" --staged >/dev/null || failed=1
fi

[ "$failed" -ne 0 ] && echo "clean-code: BLOCKED (see .claude/rules/clean-code.md and ban-comments.md; one-off override: CLEAN_CODE_SKIP=1)"
exit "$failed"
