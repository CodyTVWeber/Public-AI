#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: lint-clean-code.sh BASE
Greps lines added since the merge-base of BASE and HEAD (committed, uncommitted, untracked)
against the rules in rules/clean-code.md. Run from inside the repo.
Errors (exit 1): comment, banner (STATUS:, now unified, new approach, previously), empty_catch.
Warnings only: file_over_200 (code files), layer_folder (controller/service/model directories).
Banner phrases in dated, changelog, adr, postmortem and history docs are allowed.
Stdout: {"errors": [{file, line, rule}], "warnings": [...]}. Exit: 0 ok, 1 errors, 2 usage, 3 not a repo or bad BASE.
USAGE
}

case "${1:-}" in -h|--help) usage; exit 0 ;; esac
[ $# -eq 1 ] || { usage >&2; exit 2; }
base="$1"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not inside a git work tree" >&2; exit 3; }
git rev-parse --verify --quiet "${base}^{commit}" >/dev/null || { echo "unknown BASE: $base" >&2; exit 3; }
root=$(git rev-parse --show-toplevel)
cd "$root"
mb=$(git merge-base "$base" HEAD 2>/dev/null || git rev-parse "$base")

added() {
  git -c core.quotepath=off diff --no-ext-diff --no-color -U0 --diff-filter=ACMR "$mb" -- . | awk '
    /^\+\+\+ b\// { file = substr($0, 7); next }
    /^\+\+\+ / { file = ""; next }
    /^@@/ { match($0, /\+[0-9]+/); line = substr($0, RSTART + 1, RLENGTH - 1) + 0; next }
    /^\+/ { if (file != "") printf "%s\t%d\t%s\n", file, line, substr($0, 2); line++ }
  '
  while IFS= read -r f; do
    [ -f "$f" ] && grep -Iq . "$f" 2>/dev/null || continue
    awk -v f="$f" '{ printf "%s\t%d\t%s\n", f, NR, $0 }' "$f"
  done < <(git ls-files -o --exclude-standard)
}

analyze() {
  awk '
    function ext_of(path,   base, n) {
      base = path
      sub(/.*\//, "", base)
      if (base == "Dockerfile" || base == "Makefile") return "hash"
      n = match(base, /\.[A-Za-z0-9]+$/)
      if (!n) return ""
      return tolower(substr(base, n + 1))
    }
    function style(e) {
      if (e ~ /^(js|jsx|ts|tsx|mjs|cjs|java|kt|kts|go|rs|c|h|cc|cpp|hpp|cs|swift|scala|dart|php)$/) return "slash"
      if (e ~ /^(sh|bash|zsh|py|rb|yml|yaml|toml|pl|r|tf|conf|ini|mk|hash)$/) return "hash"
      if (e ~ /^(sql|lua|hs)$/) return "dash"
      if (e ~ /^(html|htm|xml|vue|svelte)$/) return "xml"
      if (e ~ /^(md|markdown|rst)$/) return "doc"
      return ""
    }
    function is_comment(t, st, e) {
      if (t ~ /shellcheck|eslint-|noqa|@ts-|istanbul|prettier-ignore|nolint|coding[:=]|type: ignore|pragma|frozen_string_literal|SPDX/) return 0
      if (st == "slash") return (t ~ /^\/\// || t ~ /^\/\*/ || t ~ /^\*([ \/]|$)/ || t ~ /^\{\/\*/ || t ~ /[ \t]\/\/[ \t]/)
      if (st == "hash") {
        if (t ~ /^#!/) return 0
        if (e == "py" && (t ~ /^"""/ || t ~ /^\047\047\047/)) return 1
        return (t ~ /^#/ || t ~ /[ \t]#[ \t]/)
      }
      if (st == "dash") return (t ~ /^--/)
      if (st == "xml") return (t ~ /<!--/)
      return 0
    }
    function emit(kind, file, line, rule) { printf "%s\t%s\t%d\t%s\n", kind, file, line, rule }
    BEGIN { FS = "\t" }
    {
      p1 = index($0, "\t")
      file = substr($0, 1, p1 - 1)
      rest = substr($0, p1 + 1)
      p2 = index(rest, "\t")
      line = substr(rest, 1, p2 - 1) + 0
      text = substr(rest, p2 + 1)
      if (file ~ /^scripts\/lint\//) next
      e = ext_of(file)
      st = style(e)
      if (st == "") next
      t = text
      sub(/^[ \t]+/, "", t)
      sub(/[ \t]+$/, "", t)

      historical = (tolower(file) ~ /(adr|changelog|postmortem|history|[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])/)
      if (!historical && (text ~ /STATUS:/ || tolower(text) ~ /now unified|new approach|previously/)) emit("error", file, line, "banner")
      if (st != "doc" && is_comment(t, st, e)) emit("error", file, line, "comment")

      if (st != "doc") {
        if (text ~ /catch[ \t]*(\([^)]*\))?[ \t]*\{[ \t]*\}/ || text ~ /\.catch\([^)]*=>[ \t]*\{[ \t]*\}\)/ || text ~ /except[^:]*:[ \t]*pass/) emit("error", file, line, "empty_catch")
        if (pending_file == file && pending_line + 1 == line && (t == "}" || t == "pass")) emit("error", file, pending_line, "empty_catch")
        pending_file = ""
        if (text ~ /catch[^{]*\{[ \t]*$/ || t ~ /^except[^:]*:$/) { pending_file = file; pending_line = line }
      }
    }
  '
}

structure() {
  git -c core.quotepath=off diff --no-ext-diff --name-only --diff-filter=ACMR "$mb" -- .
  git ls-files -o --exclude-standard
}

findings=$(added | analyze || true)

warnings=""
while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  case "$f" in scripts/lint/*) continue ;; esac
  case "$f" in
    *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.java|*.kt|*.kts|*.go|*.rs|*.c|*.h|*.cc|*.cpp|*.hpp|*.cs|*.swift|*.scala|*.dart|*.php|*.sh|*.bash|*.zsh|*.py|*.rb)
      n=$(wc -l <"$f" | tr -d ' ')
      if [ "$n" -gt 200 ]; then warnings+=$(printf 'warning\t%s\t0\tfile_over_200\n' "$f")$'\n'; fi ;;
  esac
  dir=$(dirname "$f")
  if printf '%s\n' "$dir" | tr '[:upper:]' '[:lower:]' | grep -Eq '(^|/)(controllers?|services?|models?)(/|$)'; then
    warnings+=$(printf 'warning\t%s\t0\tlayer_folder\n' "$dir")$'\n'
  fi
done < <(structure | sort -u)

all=$(printf '%s\n%s\n' "$findings" "$warnings" | grep -v '^$' | sort -u -t $'\t' -k1,1 -k2,2 -k3,3n -k4,4 || true)
if [ -z "$all" ]; then
  echo '{"errors":[],"warnings":[]}'
  exit 0
fi

result=$(printf '%s\n' "$all" | jq -R -s -c '
  split("\n") | map(select(length > 0) | split("\t") | {kind: .[0], file: .[1], line: (.[2] | tonumber), rule: .[3]}) as $rows
  | {errors: [$rows[] | select(.kind == "error") | del(.kind)], warnings: [$rows[] | select(.kind == "warning") | del(.kind)]}')
printf '%s\n' "$result"
[ "$(jq '.errors | length' <<<"$result")" -eq 0 ] || exit 1
