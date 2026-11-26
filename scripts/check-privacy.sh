#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: check-privacy.sh [--content | --paths | --message FILE | --range REV_RANGE] [--strict] [-h|--help]

Mechanical privacy gate for this repo (see PRIVACY.md).
  (none)          scan staged additions (content), staged file names and staged binaries
  --content       staged additions only
  --paths         staged file names only
  --message FILE  a commit message (comment lines ignored); used by the commit-msg hook
  --range REV     added lines, file names, commit messages and binaries of REV, for example
                  @{u}..HEAD; "auto" picks @{u}..HEAD, else origin/<default>..HEAD, else HEAD's
                  last commit; used by the pre-push hook
  --strict        a missing local patterns file blocks (exit 1)
Install as git hooks:  scripts/install-hooks.sh
Local patterns: the untracked file <git-dir>/info/privacy-patterns, one extended regex per line, blank
     and # lines ignored; matches block like the built-in checks. A missing file warns on stderr on
     every run, and blocks with --strict or PRIVACY_REQUIRE_PATTERNS=1.
Binaries: files git reports as binary, and png jpg jpeg gif webp pdf zip gz ico mov mp4 docx xlsx,
     block unless the path is a line of .privacyallow-binaries. Review them by hand first.
Env: PRIVACY_EMPLOYER_PATTERN  extended regex for the employer-name check (default: EMPLOYER_PATTERN
     in this file, empty = check off)
Allow list: .privacyallow, one regex per line; a flagged line matching any entry is dropped.
Exit: 0 clean, 1 blocked, 2 usage, 3 not a git repo, message file missing or bad range
EOF
}

mode=all
msgfile=""
range_arg=""
strict="${PRIVACY_REQUIRE_PATTERNS:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --content) mode=content ;;
    --paths) mode=paths ;;
    --strict) strict=1 ;;
    --message) mode=message; shift; [ $# -gt 0 ] || { usage >&2; exit 2; }; msgfile="$1" ;;
    --range) mode=range; shift; [ $# -gt 0 ] || { usage >&2; exit 2; }; range_arg="$1" ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

[ "$mode" != message ] || case "$msgfile" in /*) ;; *) msgfile="$PWD/$msgfile" ;; esac
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "check-privacy: not a git repo" >&2; exit 3; }
cd "$root"
[ "$mode" != message ] || [ -f "$msgfile" ] || { echo "check-privacy: no such file: $msgfile" >&2; exit 3; }

ALLOW_FILE=".privacyallow"
failed=0

EMPLOYER_PATTERN="${PRIVACY_EMPLOYER_PATTERN:-}"

BINARY_ALLOW_FILE=".privacyallow-binaries"
BINARY_EXT='png|jpg|jpeg|gif|webp|pdf|zip|gz|ico|mov|mp4|docx|xlsx'
SELF_EXCLUDE='^(scripts/check-privacy\.sh|\.privacyallow)$'
KNOWN_TOKENS='(SHA|UTF|ISO|AES|RSA|HMAC|ECDSA|PBKDF|CRC|HTTP|TLS|SSL|IPV|IEEE|RFC|BCP|CVE|CWE|GPT|COVID|WCAG|UTC|GMT|PEP|JEP|ASCII|ISBN|ISSN|PDF|AC)-[0-9]+'
STD_TOKENS="${KNOWN_TOKENS/GPT|/}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
CONTENT="$tmp/content"
META="$tmp/meta"
ALLOWNUMS="$tmp/allowed"
: > "$CONTENT"; : > "$META"; : > "$ALLOWNUMS"

staged_names=()
range=()
LOCAL_PATTERN=""
TRAILERS=0
patterns_file="$(git rev-parse --git-path info/privacy-patterns)"
source_cmd=(git diff --cached)

load_local_patterns() {
  local p
  if [ ! -f "$patterns_file" ]; then
    echo "check-privacy: warning: no local patterns file at $patterns_file; employer and hostname checks are generic only" >&2
    [ "$strict" = 1 ] || return 0
    echo "check-privacy: BLOCKED: --strict needs $patterns_file" >&2
    exit 1
  fi
  LOCAL_PATTERN="$(grep -Ev '^[[:space:]]*(#|$)' "$patterns_file")"
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    printf '' | grep -E -e "$p" > /dev/null 2>&1
    [ $? -le 1 ] || { echo "check-privacy: BLOCKED: invalid regex in $patterns_file" >&2; exit 1; }
  done <<< "$LOCAL_PATTERN"
}

resolve_range() {
  local base
  range=("$range_arg")
  if [ "$range_arg" = auto ]; then
    git rev-parse -q --verify HEAD > /dev/null 2>&1 || exit 0
    range=(-n1 HEAD)
    for base in '@{u}' "$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" origin/main origin/master; do
      [ -n "$base" ] && git rev-parse -q --verify "$base" > /dev/null 2>&1 || continue
      range=("$base..HEAD")
      break
    done
  fi
  git rev-list "${range[@]}" > /dev/null 2>&1 || { echo "check-privacy: bad range: $range_arg" >&2; exit 3; }
  source_cmd=(git -c core.quotepath=off log "${range[@]}" --no-merges --format=)
}

listing() {
  "${source_cmd[@]}" --no-renames --diff-filter=ACMR -z "$@"
}

collect_names() {
  local name
  while IFS= read -r -d '' name; do
    printf '%s' "$name" | grep -Eq "$SELF_EXCLUDE" && continue
    staged_names+=("$name")
  done < <(listing --name-only | sort -zu)
}

build_content() {
  [ "${#staged_names[@]}" -gt 0 ] || return 0
  "${source_cmd[@]}" -p -U0 --no-color --no-ext-diff --src-prefix=a/ --dst-prefix=b/ -- "${staged_names[@]}" \
    | CONTENT="$CONTENT" META="$META" awk '
      /^diff --git / { inhunk = 0; next }
      !inhunk && /^\+\+\+ / { f = $0; sub(/^\+\+\+ b\//, "", f); sub(/\t.*$/, "", f); next }
      /^@@ / { inhunk = 1; match($0, /\+[0-9]+/); ln = substr($0, RSTART + 1, RLENGTH - 1) + 0; next }
      inhunk && /^\+/ { print substr($0, 2) >> ENVIRON["CONTENT"]; print f ":" ln >> ENVIRON["META"]; ln++ }
    '
}

build_paths() {
  local name
  for name in "${staged_names[@]+"${staged_names[@]}"}"; do
    printf '%s\n' "$name" >> "$CONTENT"
    printf '%s\n' "$name" >> "$META"
  done
}

build_message() {
  TRAILERS=1
  awk '{ if ($0 ~ /^#/) print ""; else print }' "$msgfile" > "$CONTENT"
  awk '{ print "message:" NR }' "$CONTENT" > "$META"
}

build_range_messages() {
  local sha
  TRAILERS=1
  while IFS= read -r sha; do
    git show -s --format=%B "$sha" | awk -v id="${sha:0:7}" -v c="$CONTENT" -v m="$META" '{ print >> c; print "commit " id ":" NR >> m }'
  done < <(git rev-list "${range[@]}")
}

is_binary() {
  local added="$1" path="$2" ext
  [ "$added" = "-" ] && return 0
  case "$path" in *.*) ;; *) return 1 ;; esac
  ext="$(printf '%s' "${path##*.}" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$ext" | grep -Eq "^($BINARY_EXT)$"
}

build_binaries() {
  local rec added path
  while IFS= read -r -d '' rec; do
    rec="${rec#$'\n'}"
    added="${rec%%$'\t'*}"
    path="${rec#*$'\t'}"
    path="${path#*$'\t'}"
    is_binary "$added" "$path" || continue
    [ -f "$BINARY_ALLOW_FILE" ] && grep -Fxq -e "$path" "$BINARY_ALLOW_FILE" && continue
    printf '%s\n' "$path" | tee -a "$CONTENT" >> "$META"
  done < <(listing --numstat)
}

mark_allowed() {
  [ -s "$ALLOW_FILE" ] || return 0
  grep -Ev '^[[:space:]]*(#|$)' "$ALLOW_FILE" > "$tmp/allow.re" || true
  [ -s "$tmp/allow.re" ] || return 0
  grep -nEf "$tmp/allow.re" "$CONTENT" 2>/dev/null | cut -d: -f1 > "$ALLOWNUMS" || true
}

check() {
  local label="$1" pattern="$2" flag="$3" strip="${CHECK_STRIP:-}" src="$CONTENT" hits opt="-nE"
  [ -z "$pattern" ] && return 0
  [ "$flag" = i ] && opt="-nEi"
  if [ -n "$strip" ]; then
    sed -E "s/$strip//g" "$CONTENT" > "$tmp/stripped"
    src="$tmp/stripped"
  fi
  if [ "$TRAILERS" = 1 ] && [ "$label" = "email address" ]; then
    awk '{ if (tolower($0) ~ /^(signed-off-by|co-authored-by):/) print ""; else print }' "$src" > "$tmp/notrailers"
    src="$tmp/notrailers"
  fi
  hits="$(grep $opt -e "$pattern" "$src" 2>/dev/null \
    | awk -v m="$META" -v a="$ALLOWNUMS" '
        BEGIN { while ((getline l < m) > 0) meta[++nm] = l; while ((getline l < a) > 0) allowed[l] = 1 }
        { i = index($0, ":"); n = substr($0, 1, i - 1); text = substr($0, i + 1)
          if (n in allowed) next
          loc = (meta[n] == text) ? "path" : meta[n]
          print "    " loc ": " substr(text, 1, 160) }' \
    | head -8)"
  if [ -n "$hits" ]; then
    printf '\n  [%s]\n%s\n' "$label" "$hits"
    failed=1
  fi
}

identity_checks() {
  check "employer name" "$EMPLOYER_PATTERN" i
  check "local pattern" "$LOCAL_PATTERN" i
  check "generic internal hostname" '[a-z0-9.-]+\.(internal|corp)\b' i
  CHECK_STRIP="$KNOWN_TOKENS" check "ticket id" '\b[A-Z]{2,}-[0-9]+\b' s
  check "aws account id" '\b[0-9]{12}\b' i
  check "home directory path" '/(Users|home)/[A-Za-z0-9._-]+/' i
  check "email address" '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' i
  check "private ip address" '\b(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}\b' i
  check "git remote slug" 'git@[a-z0-9.-]+:[A-Za-z0-9._/-]+|https?://[a-z0-9.-]+/[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+\.git\b' i
  check "cloud resource arn" 'arn:aws[a-z-]*:[a-z0-9-]*:' i
  check "phone number" '(^|[^0-9])(\+?[0-9]{1,2}[ .-])?(\([0-9]{3}\)[ .-]?|[0-9]{3}[ .-])[0-9]{3}[ .-][0-9]{4}([^0-9]|$)' i
  check "po box" '\bP\.?[[:space:]]?O\.?[[:space:]]+Box[[:space:]]+[0-9]+' i
  check "street address" '\b[0-9]{1,6}[[:space:]]+([A-Z][a-z]+[[:space:]]+){1,3}(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Way|Place|Pl|Parkway|Pkwy|Highway|Hwy)\b' s
  check "city state zip" ',[[:space:]]*[A-Z]{2}[[:space:]]+[0-9]{5}(-[0-9]{4})?\b' s
}

version_checks() {
  check "semver pin" '\b[0-9]+\.[0-9]+\.[0-9]+\b' i
  check "docker image tag" '^[[:space:]]*(image|FROM)[[:space:]]*:?[[:space:]]*[a-z0-9./_-]+:[0-9]' i
  check "image-tag style pin" '[A-Za-z][A-Za-z0-9_./-]*:[0-9]+\.[0-9]+' i
  check "version element" '<version>|"version"[[:space:]]*:' i
  check "action version pin" '@v[0-9]+' i
  CHECK_STRIP="$STD_TOKENS" check "model version token" '\b[a-z]+-[0-9]+\.[0-9]+\b' i
}

secret_checks() {
  check "possible secret" '(api[_-]?key|secret|passwd|password|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}' i
  check "token-shaped secret" 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}' s
  check "private key" 'BEGIN [A-Z ]*PRIVATE KEY' i
}

scan() {
  [ -s "$CONTENT" ] || return 0
  mark_allowed
  [ "$1" != binaries ] || { check "binary file: review by hand, then list it in $BINARY_ALLOW_FILE" '.' s; return 0; }
  identity_checks
  version_checks
  [ "$1" = paths ] || secret_checks
}

section() {
  : > "$CONTENT"; : > "$META"; : > "$ALLOWNUMS"
  TRAILERS=0
  "$1"
  scan "$2"
}

load_local_patterns
[ "$mode" != range ] || resolve_range
[ "$mode" = message ] || collect_names
case "$mode" in
  content) section build_content content ;;
  paths) section build_paths paths ;;
  message) section build_message message ;;
  all|range)
    section build_content content
    section build_paths paths
    section build_binaries binaries
    [ "$mode" != range ] || section build_range_messages message
    ;;
esac

if [ "$failed" -ne 0 ]; then
  cat <<'EOF'

BLOCKED: content matched privacy rules (see PRIVACY.md).

Fix the lines above, or if a match is a false positive:
  - add a regex to .privacyallow, or
  - re-run with `git commit --no-verify` if you are certain

EOF
  exit 1
fi
exit 0
