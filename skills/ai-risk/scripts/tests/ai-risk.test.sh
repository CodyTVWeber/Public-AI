#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
new_tmp

policy="$here/../merge-policy.sh"
classify="$here/../classify-tier.sh"

pol() { printf '%s\n' "$1" > "$TMPROOT/p.md"; "$policy" "$TMPROOT/p.md"; }
field() { printf '%s' "$1" | jq -r "$2"; }

out="$("$policy" "$TMPROOT/none.md")"; rc=$?
assert_rc "missing file exits 0" 0 $rc
assert_eq "missing file conservative" conservative "$(field "$out" .profile)"
assert_eq "missing file source" default "$(field "$out" .source)"
assert_eq "missing file no auto" false "$(field "$out" .auto_merge_low)"

assert_eq "conservative" conservative "$(field "$(pol 'Merge policy: conservative')" .profile)"
assert_eq "balanced" balanced "$(field "$(pol 'Merge policy: balanced')" .profile)"
assert_eq "yolo" yolo "$(field "$(pol 'Merge policy: yolo')" .profile)"
assert_eq "case and backticks" balanced "$(field "$(pol 'merge policy: `Balanced`')" .profile)"
assert_eq "unknown value" conservative "$(field "$(pol 'Merge policy: reckless')" .profile)"
assert_eq "placeholder value" conservative "$(field "$(pol 'Merge policy: <profile>')" .profile)"
assert_eq "no line" conservative "$(field "$(pol 'nothing here')" .profile)"
assert_eq "comment stripped before parsing" balanced "$(field "$(pol $'Merge policy: balanced\n<!-- Merge policy: yolo -->')" .profile)"
assert_eq "multiline comment stripped" balanced "$(field "$(pol $'<!--\nMerge policy: yolo\n-->\nMerge policy: balanced')" .profile)"
assert_eq "commented-out only" conservative "$(field "$(pol $'<!-- Merge policy: yolo -->')" .profile)"
assert_eq "fenced example ignored" conservative "$(field "$(pol $'```\nMerge policy: yolo\n```')" .profile)"
assert_eq "disagreeing lines take the strictest" conservative "$(field "$(pol $'Merge policy: yolo\nMerge policy: conservative')" .profile)"
assert_eq "auto-merge off by default" false "$(field "$(pol 'Merge policy: balanced')" .auto_merge_low)"
assert_eq "auto-merge on for balanced" true "$(field "$(pol $'Merge policy: balanced\nAuto-merge low: on')" .auto_merge_low)"
assert_eq "auto-merge in comment ignored" false "$(field "$(pol $'Merge policy: balanced\n<!--\nAuto-merge low: on\n-->')" .auto_merge_low)"
assert_eq "auto-merge ignored outside balanced" false "$(field "$(pol $'Merge policy: yolo\nAuto-merge low: on')" .auto_merge_low)"
assert_eq "source is the file" "$TMPROOT/p.md" "$(field "$(pol 'Merge policy: yolo')" .source)"

out="$("$policy" "$here/../../assets/ai-merge-policy.md")"
assert_eq "shipped asset is conservative" conservative "$(field "$out" .profile)"
assert_eq "shipped asset auto-merge off" false "$(field "$out" .auto_merge_low)"

tier() { "$classify" --files "$@" | jq -r .tier; }
assert_eq "docs low" low "$(tier docs/guide.md)"
assert_eq "tests low" low "$(tier tests/a.test.ts src/b_test.go)"
assert_eq "styling low" low "$(tier src/app.css)"
assert_eq "app code medium" medium "$(tier src/service/orders.ts)"
assert_eq "unmatched medium" medium "$(tier something.weird)"
assert_eq "latest is not a test" medium "$(tier src/latest.ts)"
assert_eq "author is not auth" medium "$(tier src/author.ts)"
assert_eq "auth high" high "$(tier src/auth/login.ts)"
assert_eq "migration high" high "$(tier db/migrations/001_add.sql)"
assert_eq "workflow high" high "$(tier .github/workflows/ci.yml)"
assert_eq "git hook high" high "$(tier .githooks/pre-commit)"
assert_eq "manifest high" high "$(tier package.json)"
assert_eq "agent rules high" high "$(tier AGENTS.md)"
assert_eq "skill high" high "$(tier skills/x/SKILL.md)"
assert_eq "policy file high" high "$(tier docs/rules/ai-merge-policy.md)"
assert_eq "env file high" high "$(tier .env.production)"
assert_eq "env example not secret" medium "$(tier .env.example)"
assert_eq "highest wins" high "$(tier docs/guide.md src/auth/login.ts src/app.ts)"
assert_eq "medium over low" medium "$(tier docs/guide.md src/app.ts)"
assert_eq "data store script high" high "$(tier scripts/restore-db.sh)"
assert_eq "lockfile medium" medium "$(tier package-lock.json)"
assert_eq "empty list low" low "$(tier)"
out="$("$classify" --files 'dir with space/a.css' src/auth/x.ts)"
assert_eq "space path kept" "dir with space/a.css" "$(field "$out" '.reasons[0].path')"
assert_eq "reason has why" true "$(field "$out" '.reasons[1].why | length > 0')"
assert_eq "policy embedded" conservative "$(field "$out" .policy.profile)"
assert_contains "approver text" "$(field "$out" .approver)" "approval"

repo="$TMPROOT/repo"
new_repo "$repo"
git -C "$repo" checkout -q -b main
mkdir -p "$repo/docs/rules" "$repo/src"
printf 'Merge policy: balanced\n' > "$repo/docs/rules/ai-merge-policy.md"
printf 'x\n' > "$repo/README.md"
git -C "$repo" add -- .
git -C "$repo" commit -q -m base
git -C "$repo" checkout -q -b feature
printf 'y\n' >> "$repo/README.md"
printf 'code\n' > "$repo/src/app.ts"
git -C "$repo" add -- src/app.ts
git -C "$repo" commit -q -m change
out="$(cd "$repo" && "$classify" main)"; rc=$?
assert_rc "base mode ok" 0 $rc
assert_eq "base mode tier" medium "$(field "$out" .tier)"
assert_eq "base mode policy from repo" balanced "$(field "$out" .policy.profile)"
assert_contains "balanced medium approver" "$(field "$out" .approver)" "second person"
mkdir -p "$repo/.github/workflows"
printf 'on: push\n' > "$repo/.github/workflows/ci.yml"
out="$(cd "$repo" && "$classify" main)"
assert_eq "untracked file counted" high "$(field "$out" .tier)"
out="$(cd "$repo" && "$classify" no-such-ref 2>&1)"; assert_rc "bad base exits 3" 3 $?
out="$("$classify" --bogus 2>&1)"; assert_rc "bad flag" 2 $?
finish
