#!/usr/bin/env bash
set -euo pipefail
export GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
stages="$here/../stages.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0
fail=0

check() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3" >&2
  fi
}

git init -q -b main "$tmp/r"
cd "$tmp/r"
printf 'one\n' >a.txt
git add -A
git commit -q -m init

scenario() {
  local name=$1
  shift
  git checkout -q -B "t-$name" main
  local spec path text
  for spec in "$@"; do
    path=${spec%%=*}
    text=${spec#*=}
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$text" >"$path"
  done
  git add -A
  git commit -q --allow-empty -m "$name"
  out=$("$stages" main)
}

active() {
  printf '%s' "$out" | jq -r '[.stages[] | select(.active) | .id] | join(",")'
}

big="a = 1
b = 2
c = 3
d = 4
e = 5
f = 6"
on() { printf '%s' "$out" | jq -r --arg id "$1" '.stages[] | select(.id == $id) | .active'; }
reason() { printf '%s' "$out" | jq -r --arg id "$1" '.stages[] | select(.id == $id) | .reason'; }

scenario docs README.md="hello"
check "docs only" "plan,code-quality,proof" "$(active)"

scenario tiny src/util.py="x = 1"
check "tiny code change skips logic" "false" "$(on logic)"
check "tiny code change skips tests" "false" "$(on tests)"
check "tiny code change still gets quality" "true" "$(on code-quality)"

scenario plain src/util.py="$big"
check "plain code" "plan,logic,tests,code-quality,proof" "$(active)"
check "code without tests says so" "code changed, no test files touched" "$(reason tests)"
check "skill name" "review-logic" "$(printf '%s' "$out" | jq -r '.stages[] | select(.id == "logic") | .skill')"
check "added lines counted" "6" "$(printf '%s' "$out" | jq -r .added_code_lines)"

scenario nonhappy src/util.py="$big
try: x()
except ValueError: pass"
check "error handling turns on non-happy-logic" "true" "$(on non-happy-logic)"

scenario happyonly src/util.py="$big"
check "happy path leaves non-happy-logic off" "false" "$(on non-happy-logic)"

scenario withtest src/util.py="$big" tests/test_util.py="y = 2"
check "test files noted" "test files changed" "$(reason tests)"

scenario testonly tests/test_util.py="y = 2"
check "test-only change runs tests stage" "true" "$(on tests)"
check "test-only change skips logic" "false" "$(on logic)"

scenario sec src/auth/login.py="x = 1"
check "security by path" "true" "$(on security)"

scenario sec2 src/util.py="token = os.system(cmd)"
check "security by content" "true" "$(on security)"

scenario data db/migrations/001_init.sql="CREATE TABLE t (id int);"
check "data by path" "true" "$(on data)"

scenario ui web/Button.tsx="export const B = () => null"
check "ui by path" "true" "$(on ui)"
check "ui lists the file" '["web/Button.tsx"]' "$(printf '%s' "$out" | jq -c '.stages[] | select(.id == "ui") | .files')"

scenario deps package.json="{}"
check "dependencies by manifest" "true" "$(on dependencies)"

scenario infra Dockerfile="FROM base"
check "infra by path" "true" "$(on infra)"

scenario conc src/job.py="with mutex(): retry(3)"
check "concurrency by content" "true" "$(on concurrency)"

scenario docsmention README.md="the password is stored elsewhere"
check "docs prose never triggers security" "false" "$(on security)"

REVIEW_LOGIC_MIN=1 scenario lowmin src/util.py="x = 1"
check "REVIEW_LOGIC_MIN lowers the bar" "true" "$(on logic)"

git checkout -q -B t-empty main
out=$("$stages" main)
check "empty diff" "plan,proof" "$(active)"

rc=0
"$stages" no-such-ref >/dev/null 2>&1 || rc=$?
check "bad base exits 3" "3" "$rc"
rc=0
"$stages" >/dev/null 2>&1 || rc=$?
check "no args exits 2" "2" "$rc"

printf 'stages.test: pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
