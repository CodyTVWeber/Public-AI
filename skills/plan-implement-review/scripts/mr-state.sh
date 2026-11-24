#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib-forge.sh"

usage() {
  cat <<'USAGE'
usage: mr-state.sh [number]
Read-only PR/MR snapshot (glab or gh, from origin url). number defaults to the open PR/MR of the current branch.
stdout: {number, state, head_sha, conflicts, pipeline{status, failed_jobs[]}, threads{human_unresolved[], bot_count},
         behind_target, next}
state: open|merged|closed. pipeline.status: success|failed|running|pending|canceled|none (other raw values pass through).
failed_jobs[]: {id, name}. Thread: {id, author, file, line, body}. System notes and non-resolvable notes are not threads.
Bot threads (author flagged bot, or username like *-bot, *_bot_*, dependabot, renovate) are counted in
threads.bot_count (unresolved only), never listed. behind_target: commits behind target branch (null if unknown).
next, first match wins:
  done            state is merged or closed
  fix_ci          pipeline failed
  reply_threads   unresolved human threads exist
  rebase_needed   behind_target > 0 or merge conflicts
  done            pipeline success (green, no human threads)
  wait            otherwise (running, pending, none)
exit: 0 ok, 2 usage, 3 precondition (no CLI, not authenticated, no PR/MR found)
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  -*)
    usage >&2
    exit 2
    ;;
esac
[ "$#" -le 1 ] || {
  usage >&2
  exit 2
}

forge_init
forge_need_cli
n=${1:-}
if [ -z "$n" ]; then
  b=$(git branch --show-current)
  [ -n "$b" ] || die 3 "detached HEAD; pass a number"
  n=$(forge_number_for_branch "$b") || die 3 "$CLI failed listing open PRs/MRs"
  [ -n "$n" ] || die 3 "no open PR/MR for branch $b"
fi
case "$n" in
  *[!0-9]*)
    usage >&2
    exit 2
    ;;
esac

bot_re='(^|[-_.\[])bot($|[-_.0-9\]])|^(dependabot|renovate)'

if [ "$FORGE" = gitlab ]; then
  mr=$(glab api "projects/:id/merge_requests/$n?include_diverged_commits_count=true") || die 3 "glab failed for MR $n"
  pid=$(printf '%s' "$mr" | jq -r '(.head_pipeline // .pipeline // {}).id // empty')
  jobs='[]'
  if [ -n "$pid" ]; then
    jobs=$(forge_api "projects/:id/pipelines/$pid/jobs?per_page=100") || die 3 "glab failed for pipeline $pid"
  fi
  disc=$(forge_api "projects/:id/merge_requests/$n/discussions?per_page=100") || die 3 "glab failed for discussions"
  base=$(jq -n --argjson mr "$mr" --argjson jobs "$jobs" --argjson disc "$disc" '
    ($mr.head_pipeline // $mr.pipeline // null) as $p
    | {number: $mr.iid,
       state: (if $mr.state == "merged" then "merged" elif $mr.state == "closed" then "closed" else "open" end),
       head_sha: $mr.sha,
       conflicts: ($mr.has_conflicts // false),
       behind_target: ($mr.diverged_commits_count // null),
       pipeline: {
         status: (if $p == null then "none"
                  elif $p.status == "canceled" or $p.status == "cancelled" then "canceled"
                  elif ($p.status | IN("created", "waiting_for_resource", "preparing", "scheduled")) then "pending"
                  else $p.status end),
         failed_jobs: ($jobs | map(select(.status == "failed" and ((.allow_failure // false) | not)) | {id: .id, name: .name}))},
       threads: ($disc
         | map(. as $d | $d.notes[0] as $f
               | select($f != null and (($f.system // false) | not) and any($d.notes[]; .resolvable // false))
               | {id: $d.id,
                  resolved: all($d.notes[] | select(.resolvable // false); .resolved // false),
                  author: ($f.author.username // null),
                  bot: ($f.author.bot // false),
                  file: ($f.position.new_path // $f.position.old_path // null),
                  line: ($f.position.new_line // $f.position.old_line // null),
                  body: ($f.body // "" | .[0:200])}))}')
else
  owner=${PROJECT%%/*}
  repo=${PROJECT#*/}
  pr=$(gh pr view "$n" --json number,state,headRefOid,baseRefName,mergeable,statusCheckRollup) || die 3 "gh failed for PR $n"
  gq='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first:100){nodes{id isResolved path line comments(first:1){nodes{body author{login __typename}}}}}}}}'
  disc=$(gh api graphql -f query="$gq" -F owner="$owner" -F name="$repo" -F number="$n" |
    jq -c '.data.repository.pullRequest.reviewThreads.nodes // []') || die 3 "gh failed for review threads"
  sha=$(printf '%s' "$pr" | jq -r .headRefOid)
  tbase=$(printf '%s' "$pr" | jq -r .baseRefName)
  behind=$(gh api "repos/$PROJECT/compare/$tbase...$sha" --jq .behind_by 2>/dev/null || true)
  case "$behind" in
    "" | *[!0-9]*) behind=null ;;
  esac
  base=$(jq -n --argjson pr "$pr" --argjson disc "$disc" --argjson behind "$behind" '
    ($pr.statusCheckRollup // []) as $checks
    | ($checks | map(select(
        (.conclusion // "" | IN("FAILURE", "TIMED_OUT", "STARTUP_FAILURE", "ACTION_REQUIRED", "CANCELLED"))
        or (.state // "" | IN("FAILURE", "ERROR"))))) as $failed
    | ($checks | map(select(
        ((.status // "COMPLETED") != "COMPLETED") or (.state // "" | IN("PENDING", "EXPECTED"))))) as $running
    | {number: $pr.number,
       state: ($pr.state | ascii_downcase),
       head_sha: $pr.headRefOid,
       conflicts: ($pr.mergeable == "CONFLICTING"),
       behind_target: $behind,
       pipeline: {
         status: (if ($failed | length) > 0 then "failed"
                  elif ($running | length) > 0 then "running"
                  elif ($checks | length) == 0 then "none"
                  else "success" end),
         failed_jobs: ($failed | map({id: ((.detailsUrl // "") | capture("/job/(?<j>[0-9]+)").j // null), name: (.name // .context)}))},
       threads: ($disc
         | map(. as $t | ($t.comments.nodes[0] // {}) as $f
               | {id: $t.id,
                  resolved: $t.isResolved,
                  author: ($f.author.login // null),
                  bot: (($f.author.__typename // "") == "Bot"),
                  file: $t.path,
                  line: $t.line,
                  body: ($f.body // "" | .[0:200])}))}')
fi

printf '%s' "$base" | jq -c --arg re "$bot_re" '
  def isbot: .bot or ((.author // "") | test($re; "i"));
  (.threads | map(select(.resolved | not))) as $open
  | .threads = {
      human_unresolved: ($open | map(select(isbot | not) | {id, author, file, line, body})),
      bot_count: ($open | map(select(isbot)) | length)}
  | .next = (if .state != "open" then "done"
             elif .pipeline.status == "failed" then "fix_ci"
             elif (.threads.human_unresolved | length) > 0 then "reply_threads"
             elif ((.behind_target // 0) > 0 or .conflicts) then "rebase_needed"
             elif .pipeline.status == "success" then "done"
             else "wait" end)'
