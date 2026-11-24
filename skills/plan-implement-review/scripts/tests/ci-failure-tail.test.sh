#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/forge-helpers.sh"
ct="$scripts/ci-failure-tail.sh"

make_stub_clis
mk_repo "$tmp" "https://gitlab.example.test/grp/proj"
cd "$tmp/work"

cat >"$stubs/mr.json" <<'JSON'
{"iid": 7, "state": "opened", "sha": "abc123", "has_conflicts": false, "diverged_commits_count": 0,
 "head_pipeline": {"id": 55, "status": "failed"}}
JSON
cat >"$stubs/jobs.json" <<'JSON'
[
  {"id": 101, "name": "lint", "status": "failed", "allow_failure": false},
  {"id": 102, "name": "unit", "status": "failed", "allow_failure": false}
]
JSON
echo '[]' >"$stubs/discussions.json"
esc=$(printf '\033')
{
  printf 'section_start:1700000000:step_script\r%s[0K%s[32;1mRunning%s[0;m\n' "$esc" "$esc" "$esc"
  i=1
  while [ "$i" -le 200 ]; do
    printf 'line %s\n' "$i"
    i=$((i + 1))
  done
  printf '\n\n'
  printf 'progress 10%%\rprogress 100%%\n'
  printf '%s[31;1mERROR: job failed%s[0;m\n' "$esc" "$esc"
  printf 'section_end:1700000001:step_script\r%s[0K\n' "$esc"
} >"$stubs/trace.txt"

run "$ct" 7
check "default exit" 0 "$rc"
check "default 80 lines" 80 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
check "last line cleaned" "ERROR: job failed" "$(printf '%s\n' "$out" | tail -1)"
check "no escape codes" 0 "$(printf '%s' "$out" | grep -c "$esc" || true)"
check "no section markers" 0 "$(printf '%s' "$out" | grep -c 'section_' || true)"
check "no blank lines" 0 "$(printf '%s\n' "$out" | grep -c '^$' || true)"
check "cr split progress" 1 "$(printf '%s\n' "$out" | grep -c '^progress 100%$' || true)"
case "$err" in *"lint (101)"*) check "first failed job chosen" ok ok ;; *) check "first failed job chosen" ok "$err" ;; esac

run "$ct" 7 --lines 3
check "custom lines" 3 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"

run "$ct" 7 unit
case "$err" in *"unit (102)"*) check "job by name" ok ok ;; *) check "job by name" ok "$err" ;; esac
run "$ct" 7 102 --lines 2
case "$err" in *"unit (102)"*) check "job by id" ok ok ;; *) check "job by id" ok "$err" ;; esac
check "job by id lines" 2 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"

run "$ct" 7 missing
check "unknown job exit" 1 "$rc"

echo '[{"id": 103, "name": "build", "status": "success"}]' >"$stubs/jobs.json"
run "$ct" 7
check "no failed job exit" 1 "$rc"
no_mutations "gitlab read-only"

: >"$stubs/calls.log"
git remote set-url origin "ssh://github.example.test/grp/proj"
cat >"$stubs/gh_view.json" <<'JSON'
{"number": 12, "state": "OPEN", "headRefOid": "def456", "baseRefName": "main", "mergeable": "MERGEABLE",
 "statusCheckRollup": [
  {"__typename": "CheckRun", "name": "unit", "status": "COMPLETED", "conclusion": "FAILURE",
   "detailsUrl": "https://github.example.test/grp/proj/actions/runs/900/job/4411"},
  {"__typename": "StatusContext", "context": "external", "state": "FAILURE"}]}
JSON
echo '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}' >"$stubs/gh_graphql.json"
echo 0 >"$stubs/compare.txt"
run "$ct" 12 --lines 4
check "github exit" 0 "$rc"
check "github lines" 4 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
grep -q 'run view --job 4411 --log-failed' "$stubs/calls.log" && check "github used job id" ok ok || check "github used job id" ok "$(cat "$stubs/calls.log")"
run "$ct" 12 external
check "check without log exit" 1 "$rc"
no_mutations "github read-only"

run "$ct"
check "no args exit" 2 "$rc"
run "$ct" 7 --lines x
check "bad lines exit" 2 "$rc"
run "$ct" --help
check "help exit" 0 "$rc"

finish
