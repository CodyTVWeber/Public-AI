#!/usr/bin/env bash
# Mechanical privacy gate for this personal public repo. See PRIVACY.md.
#
# Scans STAGED content only. Exit 0 = safe to commit, 1 = blocked.
# Run directly to check the current staging area:  scripts/check-privacy.sh
# Installed as a pre-commit hook by:               scripts/install-hooks.sh
#
# Escape hatches:
#   - add a regex line to .privacyallow to whitelist a known-safe pattern
#   - `git commit --no-verify` bypasses entirely (use deliberately)

set -uo pipefail

ALLOW_FILE=".privacyallow"
failed=0

# Fill this in with your own employer's name/domain, pipe-separated regex
# alternatives, e.g. 'acme[[:space:]-]*corp|acmecorp'. Left blank = no-op.
EMPLOYER_PATTERN=''

# The gate's own files are excluded: they necessarily contain the patterns they
# search for, so scanning them is guaranteed self-matching noise.
SELF_EXCLUDE='^(scripts/check-privacy\.sh|\.privacyallow)$'

staged_files() {
  git diff --cached --name-only --diff-filter=ACMR | grep -Ev "$SELF_EXCLUDE" || true
}

# Added lines only (leading '+' stripped), excluding the +++ header.
staged_additions() {
  git diff --cached -U0 -- $(staged_files) 2>/dev/null \
    | grep -E '^\+' | grep -Ev '^\+\+\+' | sed 's/^\+//'
}

filter_allowed() {
  if [ -s "$ALLOW_FILE" ]; then
    grep -Evf <(grep -Ev '^\s*(#|$)' "$ALLOW_FILE") || true
  else
    cat
  fi
}

check() {
  local label="$1" pattern="$2"
  [ -z "$pattern" ] && return 0
  local hits
  hits=$(staged_additions | grep -nEi "$pattern" | filter_allowed | head -8)
  if [ -n "$hits" ]; then
    printf '\n  [%s]\n' "$label"
    printf '%s\n' "$hits" | sed 's/^/    /'
    failed=1
  fi
}

if [ -z "$(staged_files)" ]; then
  exit 0
fi

# Employer / internal identifiers — customize EMPLOYER_PATTERN above
check "employer name"        "$EMPLOYER_PATTERN"
check "generic internal hostname" '[a-z0-9.-]+\.(internal|corp)\b'
check "ticket id"            '\b[A-Z]{2,}-[0-9]{2,}\b'
check "aws account id"       '\b[0-9]{12}\b'

# Version pins — name the technology, not the release
check "semver pin"           '\b[0-9]+\.[0-9]+\.[0-9]+\b'
check "docker image tag"     '^[[:space:]]*(image|FROM)[[:space:]]*:?[[:space:]]*[a-z0-9./_-]+:[0-9]'
check "version element"      '<version>|"version"[[:space:]]*:'

# Secrets
check "possible secret"      '(api[_-]?key|secret|passwd|password|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}'
check "private key"          'BEGIN [A-Z ]*PRIVATE KEY'

if [ "$failed" -ne 0 ]; then
  cat <<'EOF'

BLOCKED: staged content matched privacy rules (see PRIVACY.md).

Fix the lines above, or if a match is a false positive:
  - add a regex to .privacyallow, or
  - re-run with `git commit --no-verify` if you are certain

EOF
  exit 1
fi

exit 0
