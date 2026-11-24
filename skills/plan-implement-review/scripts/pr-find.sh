#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-forge.sh"

usage() {
  cat <<'USAGE'
usage: pr-find.sh <branch> [topic-token]
Read-only lookup of open PRs/MRs (glab or gh, from origin url). Never creates anything.
head_pr: open PR/MR whose source branch equals <branch> exactly, else null.
topic_prs: other open PRs/MRs whose title or branch contains topic-token (case-insensitive substring).
stdout: {head_pr, topic_prs[], action}; PR object = {number, url, branch, title, base}
action: reuse (head_pr found) | conflict (no head_pr, topic_prs found) | create (neither)
exit: 0 reuse or create, 1 conflict, 2 usage, 3 precondition (no CLI, not authenticated, unknown forge)
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

branch=$1
token=${2:-}
forge_init
forge_need_cli
open=$(forge_list_open) || die 3 "$CLI failed listing open PRs/MRs"

result=$(printf '%s' "$open" | jq -c --arg b "$branch" --arg t "$token" '
  (map(select(.branch == $b)) | .[0]) as $head
  | ($t | ascii_downcase) as $tok
  | (if $tok == "" then []
     else map(select(.branch != $b and ((.title | ascii_downcase | contains($tok)) or (.branch | ascii_downcase | contains($tok)))))
     end) as $topic
  | {head_pr: $head, topic_prs: $topic,
     action: (if $head != null then "reuse" elif ($topic | length) > 0 then "conflict" else "create" end)}')

printf '%s\n' "$result"
[ "$(printf '%s' "$result" | jq -r .action)" != conflict ] || exit 1
