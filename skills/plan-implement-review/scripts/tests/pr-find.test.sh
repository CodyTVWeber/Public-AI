#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/forge-helpers.sh"
pf="$scripts/pr-find.sh"

make_stub_clis
mk_repo "$tmp" "https://gitlab.example.test/grp/proj"
cd "$tmp/work"

cat >"$stubs/mr_list.json" <<'JSON'
[
  {"iid": 7, "web_url": "https://gitlab.example.test/grp/proj/-/merge_requests/7", "source_branch": "plan/widget-export", "title": "Plan: Widget Export", "target_branch": "main"},
  {"iid": 9, "web_url": "https://gitlab.example.test/grp/proj/-/merge_requests/9", "source_branch": "fix/other", "title": "Fix gadget sync", "target_branch": "main"}
]
JSON

run "$pf" plan/widget-export widget
check "gitlab reuse exit" 0 "$rc"
jcheck "gitlab reuse action" .action '"reuse"'
jcheck "gitlab head number" .head_pr.number 7
jcheck "gitlab head url" .head_pr.url '"https://gitlab.example.test/grp/proj/-/merge_requests/7"'
jcheck "head excluded from topics" '.topic_prs | length' 0

run "$pf" fix/new-branch WIDGET
check "gitlab conflict exit" 1 "$rc"
jcheck "gitlab conflict action" .action '"conflict"'
jcheck "topic matched by title/branch, case-insensitive" '.topic_prs | map(.number)' '[7]'
jcheck "head null" .head_pr null

run "$pf" fix/new-branch gadget
jcheck "topic by title" '.topic_prs | map(.number)' '[9]'

run "$pf" fix/new-branch widget-expor7
check "no fuzzy match exit" 0 "$rc"
jcheck "no fuzzy match action" .action '"create"'

run "$pf" plan/widget
jcheck "exact branch only, no prefix match" .action '"create"'

run "$pf" plan/widget-export-v2
jcheck "longer branch name no match" .action '"create"'

run "$pf" fix/new-branch
jcheck "no token never conflicts" .action '"create"'

echo '[]' >"$stubs/mr_list.json"
run "$pf" fix/new-branch widget
jcheck "empty list create" .action '"create"'
jcheck "empty topics" .topic_prs '[]'

touch "$stubs/cli.fail"
run "$pf" fix/new-branch widget
check "cli failure exit" 3 "$rc"
rm "$stubs/cli.fail"
no_mutations "gitlab read-only"

: >"$stubs/calls.log"
git remote set-url origin "ssh://github.example.test/grp/proj"
cat >"$stubs/gh_list.json" <<'JSON'
[
  {"number": 3, "url": "https://github.example.test/grp/proj/pull/3", "headRefName": "feat/search", "title": "Add search", "baseRefName": "main"},
  {"number": 4, "url": "https://github.example.test/grp/proj/pull/4", "headRefName": "feat/search-v2", "title": "Search follow-up", "baseRefName": "main"}
]
JSON
run "$pf" feat/search search
jcheck "github reuse" .action '"reuse"'
jcheck "github head" .head_pr '{"number":3,"url":"https://github.example.test/grp/proj/pull/3","branch":"feat/search","title":"Add search","base":"main"}'
jcheck "github other topic listed" '.topic_prs | map(.number)' '[4]'
run "$pf" feat/new nothing
jcheck "github create" .action '"create"'
check "github used gh" "pr list" "$(head -1 "$stubs/calls.log" | cut -d' ' -f1-2)"
no_mutations "github read-only"

run "$pf"
check "no args exit" 2 "$rc"
run "$pf" --help
check "help exit" 0 "$rc"

finish
