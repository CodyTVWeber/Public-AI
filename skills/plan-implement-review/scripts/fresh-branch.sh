#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-forge.sh"

usage() {
  cat <<'USAGE'
usage: fresh-branch.sh <name> [base]
Fetch, then create and check out <name> from a remote ref (no upstream tracking set).
base: default origin/<default branch>. A base of the form origin/<b> is fetched first.
Refuses a dirty tree and an existing local branch. Never stashes, resets, or pushes.
stdout: {branch, base, base_sha, previous_branch}
exit: 0 ok, 2 usage, 3 precondition (dirty tree, fetch failed, branch exists, base missing)
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  "")
    usage >&2
    exit 2
    ;;
esac
[ "$#" -le 2 ] || {
  usage >&2
  exit 2
}

name=$1
base=${2:-}
git_init
git check-ref-format --branch "$name" >/dev/null 2>&1 || die 2 "invalid branch name: $name"

dirty=$(git status --porcelain)
if [ -n "$dirty" ]; then
  printf '%s\n' "dirty working tree; handle it first:" "$dirty" >&2
  exit 3
fi

if [ -z "$base" ]; then
  default=$(forge_default_branch online) || die 3 "cannot determine default branch"
  base="origin/$default"
fi

case "$base" in
  origin/*) git fetch --quiet origin "${base#origin/}" || die 3 "fetch failed for $base" ;;
esac

git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die 3 "base ref not found: $base"
if git show-ref --verify --quiet "refs/heads/$name"; then
  die 3 "local branch already exists: $name"
fi

previous=$(git branch --show-current)
git checkout --quiet --no-track -b "$name" "$base"

jq -nc --arg branch "$name" --arg base "$base" --arg sha "$(git rev-parse HEAD)" --arg prev "$previous" \
  '{branch: $branch, base: $base, base_sha: $sha, previous_branch: (if $prev == "" then null else $prev end)}'
