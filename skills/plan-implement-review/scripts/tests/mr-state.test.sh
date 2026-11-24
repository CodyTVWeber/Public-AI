#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/forge-helpers.sh"
ms="$scripts/mr-state.sh"

make_stub_clis
mk_repo "$tmp" "https://gitlab.example.test/grp/proj"
cd "$tmp/work"
git checkout -q -b feat/widget

cat >"$stubs/mr_list.json" <<'JSON'
[{"iid": 7, "web_url": "u", "source_branch": "feat/widget", "title": "Widget", "target_branch": "main"}]
JSON
cat >"$stubs/mr.json" <<'JSON'
{"iid": 7, "state": "opened", "sha": "abc123", "has_conflicts": false, "diverged_commits_count": 0,
 "head_pipeline": {"id": 55, "status": "failed"}}
JSON
cat >"$stubs/jobs.json" <<'JSON'
[
  {"id": 101, "name": "lint", "stage": "test", "status": "failed", "allow_failure": false},
  {"id": 102, "name": "flaky", "stage": "test", "status": "failed", "allow_failure": true},
  {"id": 103, "name": "build", "stage": "build", "status": "success", "allow_failure": false}
]
JSON
cat >"$stubs/discussions.json" <<'JSON'
[
  {"id": "d1", "individual_note": false, "notes": [
    {"id": 1, "system": false, "resolvable": true, "resolved": false, "author": {"username": "alice"},
     "position": {"new_path": "src/a.kt", "new_line": 12}, "body": "please rename this"}]},
  {"id": "d2", "individual_note": false, "notes": [
    {"id": 2, "system": false, "resolvable": true, "resolved": true, "author": {"username": "bob"},
     "position": {"new_path": "src/b.kt", "new_line": 3}, "body": "done already"}]},
  {"id": "d3", "individual_note": true, "notes": [
    {"id": 3, "system": true, "resolvable": false, "author": {"username": "alice"}, "body": "added 1 commit"}]},
  {"id": "d4", "individual_note": true, "notes": [
    {"id": 4, "system": false, "resolvable": false, "author": {"username": "project_5_bot_xyz"}, "body": "scan summary"}]},
  {"id": "d5", "individual_note": false, "notes": [
    {"id": 5, "system": false, "resolvable": true, "resolved": false, "author": {"username": "scanner-bot"},
     "position": {"new_path": "src/c.kt", "new_line": 1}, "body": "finding"}]},
  {"id": "d6", "individual_note": true, "notes": [
    {"id": 6, "system": false, "resolvable": false, "author": {"username": "carol"}, "body": "general remark"}]}
]
JSON

run "$ms"
check "default number exit" 0 "$rc"
jcheck "number from branch" .number 7
jcheck "state" .state '"open"'
jcheck "head_sha" .head_sha '"abc123"'
jcheck "pipeline status" .pipeline.status '"failed"'
jcheck "failed jobs exclude allow_failure and success" .pipeline.failed_jobs '[{"id":101,"name":"lint"}]'
jcheck "human threads only" '.threads.human_unresolved | map(.id)' '["d1"]'
jcheck "thread detail" '.threads.human_unresolved[0] | [.author, .file, .line, .body]' '["alice","src/a.kt",12,"please rename this"]'
jcheck "bot count" .threads.bot_count 1
jcheck "next fix_ci" .next '"fix_ci"'

setmr() {
  local pipe=$1 behind=$2 state=${3:-opened} conflicts=${MR_CONFLICTS:-false}
  jq -n --argjson p "$pipe" --argjson b "$behind" --arg s "$state" --argjson c "$conflicts" \
    '{iid: 7, state: $s, sha: "abc123", has_conflicts: $c, diverged_commits_count: $b, head_pipeline: $p}' >"$stubs/mr.json"
}

setmr '{"id":55,"status":"success"}' 0
run "$ms" 7
jcheck "green with human thread" .next '"reply_threads"'

jq 'map(select(.id != "d1"))' "$stubs/discussions.json" >"$stubs/d.tmp"
mv "$stubs/d.tmp" "$stubs/discussions.json"
run "$ms" 7
jcheck "green no human threads" .next '"done"'
jcheck "human_unresolved empty" .threads.human_unresolved '[]'

setmr '{"id":55,"status":"success"}' 3
run "$ms" 7
jcheck "behind" .behind_target 3
jcheck "behind next" .next '"rebase_needed"'

MR_CONFLICTS=true setmr '{"id":55,"status":"success"}' 0 opened
run "$ms" 7
jcheck "conflicts next" .next '"rebase_needed"'

setmr '{"id":55,"status":"running"}' 0
run "$ms" 7
jcheck "running" .next '"wait"'
setmr '{"id":55,"status":"created"}' 0
run "$ms" 7
jcheck "created is pending" .pipeline.status '"pending"'
setmr 'null' 0
run "$ms" 7
jcheck "no pipeline" .pipeline '{"status":"none","failed_jobs":[]}'
jcheck "no pipeline waits" .next '"wait"'
setmr '{"id":55,"status":"failed"}' 5 merged
run "$ms" 7
jcheck "merged state" .state '"merged"'
jcheck "merged is done" .next '"done"'
setmr '{"id":55,"status":"success"}' 0 closed
run "$ms" 7
jcheck "closed is done" .next '"done"'

no_mutations "gitlab read-only"

touch "$stubs/cli.fail"
run "$ms" 7
check "cli failure exit" 3 "$rc"
rm "$stubs/cli.fail"

: >"$stubs/calls.log"
git remote set-url origin "ssh://github.example.test/grp/proj"
cat >"$stubs/gh_list.json" <<'JSON'
[{"number": 12, "url": "u", "headRefName": "feat/widget", "title": "Widget", "baseRefName": "main"}]
JSON
cat >"$stubs/gh_view.json" <<'JSON'
{"number": 12, "state": "OPEN", "headRefOid": "def456", "baseRefName": "main", "mergeable": "MERGEABLE",
 "statusCheckRollup": [
  {"__typename": "CheckRun", "name": "unit", "status": "COMPLETED", "conclusion": "FAILURE",
   "detailsUrl": "https://github.example.test/grp/proj/actions/runs/900/job/4411"},
  {"__typename": "CheckRun", "name": "lint", "status": "COMPLETED", "conclusion": "SUCCESS", "detailsUrl": ""},
  {"__typename": "StatusContext", "context": "external", "state": "SUCCESS"}]}
JSON
cat >"$stubs/gh_graphql.json" <<'JSON'
{"data": {"repository": {"pullRequest": {"reviewThreads": {"nodes": [
  {"id": "t1", "isResolved": false, "path": "web/app.ts", "line": 8,
   "comments": {"nodes": [{"body": "why?", "author": {"login": "dana", "__typename": "User"}}]}},
  {"id": "t2", "isResolved": true, "path": "web/b.ts", "line": 2,
   "comments": {"nodes": [{"body": "ok", "author": {"login": "erin", "__typename": "User"}}]}},
  {"id": "t3", "isResolved": false, "path": "web/c.ts", "line": 4,
   "comments": {"nodes": [{"body": "alert", "author": {"login": "scanner", "__typename": "Bot"}}]}}
]}}}}}
JSON
echo 2 >"$stubs/compare.txt"

run "$ms"
check "github exit" 0 "$rc"
jcheck "github number" .number 12
jcheck "github state" .state '"open"'
jcheck "github sha" .head_sha '"def456"'
jcheck "github pipeline" .pipeline '{"status":"failed","failed_jobs":[{"id":"4411","name":"unit"}]}'
jcheck "github human threads" '.threads.human_unresolved | map(.id)' '["t1"]'
jcheck "github bot count" .threads.bot_count 1
jcheck "github behind" .behind_target 2
jcheck "github next" .next '"fix_ci"'

jq '.statusCheckRollup[0].conclusion = "SUCCESS"' "$stubs/gh_view.json" >"$stubs/v.tmp"
mv "$stubs/v.tmp" "$stubs/gh_view.json"
jq '.statusCheckRollup[1] = {"__typename":"CheckRun","name":"lint","status":"IN_PROGRESS","conclusion":null}' "$stubs/gh_view.json" >"$stubs/v.tmp"
mv "$stubs/v.tmp" "$stubs/gh_view.json"
run "$ms" 12
jcheck "github running pipeline" .pipeline.status '"running"'
no_mutations "github read-only"

run "$ms" abc
check "bad number exit" 2 "$rc"
run "$ms" --help
check "help exit" 0 "$rc"

finish
