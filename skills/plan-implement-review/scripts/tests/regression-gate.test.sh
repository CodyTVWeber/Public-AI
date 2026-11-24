#!/usr/bin/env bash
set -uo pipefail
S="$(cd "$(dirname "$0")/.." && pwd)/regression-gate.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass=0
fail=0
eq() { if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: want [$3] got [$2]" >&2; fi; }

newrepo() {
  local d="$tmp/$1"
  mkdir -p "$d"
  git -C "$d" init -q -b main
  git -C "$d" config user.email tester
  git -C "$d" config user.name Tester
  echo "$d"
}
commit() { git -C "$1" add -A && git -C "$1" commit -qm "${2:-change}"; }
disc() { "$S" "$1" --discover-only 2>/dev/null; }

r="$(newrepo docs)"
printf '# Rules\nSystem regression: `make slow`\nPIR end gate: `bash gate.sh`\n' >"$r/AGENTS.md"
printf 'echo gate-ran\n' >"$r/gate.sh"
printf 'regression:\n\ttrue\n' >"$r/Makefile"
commit "$r"
eq "docs win over make" "$(disc "$r" | jq -r .command)" "make slow"
eq "docs source" "$(disc "$r" | jq -r .source)" "AGENTS.md"
out="$("$S" "$r" 2>/dev/null)"
eq "docs pick make slow, not defined" "$(jq -r .status <<<"$out")" failed

r="$(newrepo docsok)"
printf 'The PIR end gate is `bash gate.sh` before merge.\n' >"$r/AGENTS.md"
printf 'echo gate-ran\n' >"$r/gate.sh"
commit "$r"
out="$("$S" "$r" 2>/dev/null)"
rc=$?
eq "pass rc" "$rc" 0
eq "pass status" "$(jq -r .status <<<"$out")" passed
eq "pass command" "$(jq -r .command <<<"$out")" "bash gate.sh"
eq "pass tail" "$(jq -r .log_tail <<<"$out")" "gate-ran"

r="$(newrepo notacmd)"
printf 'System regression: see `docs/rules/testing.md` for details\n' >"$r/AGENTS.md"
commit "$r"
eq "non-command span ignored" "$(disc "$r" | jq -c .command)" null

r="$(newrepo testingdoc)"
mkdir -p "$r/docs/rules"
printf 'Regression gate: `make verify`\n' >"$r/docs/rules/testing.md"
commit "$r"
eq "testing.md source" "$(disc "$r" | jq -r .source)" "docs/rules/testing.md"

r="$(newrepo pkg)"
printf '{"scripts":{"lint":"x","test":"y","typecheck":"z","test:system:regression":"w"}}\n' >"$r/package.json"
commit "$r"
eq "explicit script beats chain" "$(disc "$r" | jq -r .command)" "npm run test:system:regression"
printf '{"scripts":{"lint":"x","test":"y","typecheck":"z"}}\n' >"$r/package.json"
eq "chain order lint typecheck test" "$(disc "$r" | jq -r .command)" "npm run lint && npm run typecheck && npm run test"
printf '{"scripts":{"test":"echo \\"Error: no test specified\\" && exit 1"}}\n' >"$r/package.json"
eq "placeholder test ignored" "$(disc "$r" | jq -c .command)" null
printf '{"scripts":{"test":"y"}}\n' >"$r/package.json"
: >"$r/pnpm-lock.yaml"
eq "pnpm runner" "$(disc "$r" | jq -r .command)" "pnpm run test"
rm "$r/pnpm-lock.yaml"
: >"$r/yarn.lock"
eq "yarn runner" "$(disc "$r" | jq -r .command)" "yarn test"

r="$(newrepo make)"
printf 'lint:\n\ttrue\ntest:\n\ttrue\n' >"$r/Makefile"
commit "$r"
eq "make chain" "$(disc "$r" | jq -r .command)" "make lint && make test"
printf 'check:\n\ttrue\n' >"$r/Makefile"
eq "make check" "$(disc "$r" | jq -r .command)" "make check"
printf 'regression:\n\ttrue\ntest:\n\ttrue\n' >"$r/Makefile"
eq "make regression" "$(disc "$r" | jq -r .command)" "make regression"

r="$(newrepo pom)"
printf '<project/>\n' >"$r/pom.xml"
eq "pom" "$(disc "$r" | jq -r .command)" "mvn -B verify"

r="$(newrepo py)"
printf '[tool.ruff]\nline-length = 100\n[tool.mypy]\nstrict = true\n[tool.pytest.ini_options]\naddopts = "-q"\n' >"$r/pyproject.toml"
eq "python chain" "$(disc "$r" | jq -r .command)" "ruff check . && mypy . && pytest"

r="$(newrepo prec)"
printf '{"scripts":{"test":"y"}}\n' >"$r/package.json"
printf 'test:\n\ttrue\n' >"$r/Makefile"
printf '<project/>\n' >"$r/pom.xml"
eq "package.json first among chains" "$(disc "$r" | jq -r .source)" "package.json"

r="$(newrepo none)"
echo hi >"$r/README"
commit "$r"
out="$("$S" "$r" 2>/dev/null)"
rc=$?
eq "skipped rc" "$rc" 0
eq "skipped status" "$(jq -r .status <<<"$out")" skipped
eq "skipped command null" "$(jq -c .command <<<"$out")" null

r="$(newrepo fail)"
printf 'test:\n\t@i=1; while [ $$i -le 60 ]; do echo line$$i; i=$$((i+1)); done; echo "FAIL: boom"; exit 1\n' >"$r/Makefile"
commit "$r"
out="$("$S" "$r" 2>/dev/null)"
rc=$?
eq "fail rc" "$rc" 1
eq "fail status" "$(jq -r .status <<<"$out")" failed
eq "tail is 40 lines" "$(jq -r .log_tail <<<"$out" | wc -l | tr -d ' ')" 40
eq "tail keeps failure line" "$(jq -r .log_tail <<<"$out" | grep -c 'FAIL: boom')" 1
eq "tail drops early lines" "$(jq -r .log_tail <<<"$out" | grep -c '^line1$')" 0
eq "no base fields without --base" "$(jq -c 'has("pre_existing")' <<<"$out")" false

echo dirt >"$r/untracked.txt"
"$S" "$r" >/dev/null 2>&1
eq "dirty tree rc" "$?" 3
rm "$r/untracked.txt"
echo more >>"$r/Makefile"
"$S" "$r" >/dev/null 2>&1
eq "modified tree rc" "$?" 3
git -C "$r" checkout -q -- Makefile

r="$(newrepo base)"
printf 'PIR end gate: `bash gate.sh`\n' >"$r/AGENTS.md"
printf 'echo "FAIL: test_a (12ms)"\nexit 1\n' >"$r/gate.sh"
commit "$r" base
git -C "$r" checkout -q -b feat
out="$("$S" "$r" --base main 2>/dev/null)"
rc=$?
eq "same failure rc" "$rc" 1
eq "same failure pre_existing" "$(jq -c .pre_existing <<<"$out")" true
eq "same failure new count" "$(jq -c .new_failures <<<"$out")" 0
eq "base status" "$(jq -r .base_status <<<"$out")" failed
printf 'echo "FAIL: test_a (30ms)"\necho "FAIL: test_b"\nexit 1\n' >"$r/gate.sh"
commit "$r" feat
out="$("$S" "$r" --base main 2>/dev/null)"
eq "new failure pre_existing false" "$(jq -c .pre_existing <<<"$out")" false
eq "new failure count" "$(jq -c .new_failures <<<"$out")" 1
eq "test_a labelled" "$(jq -r '.failures[] | select(.line | startswith("FAIL: test_a")) | .pre_existing' <<<"$out")" true
eq "test_b labelled" "$(jq -r '.failures[] | select(.line == "FAIL: test_b") | .pre_existing' <<<"$out")" false
eq "branch untouched" "$(git -C "$r" rev-parse --abbrev-ref HEAD)" feat
eq "tree still clean" "$(git -C "$r" status --porcelain)" ""

printf 'echo ok\n' >"$r/gate.sh"
commit "$r" fixed
out="$("$S" "$r" --base main 2>/dev/null)"
eq "passing head ignores base" "$(jq -r .status <<<"$out")" passed
"$S" "$r" --base no-such-ref >/dev/null 2>&1
eq "passing head with bad base rc" "$?" 0
printf 'echo "FAIL: x"\nexit 1\n' >"$r/gate.sh"
commit "$r" broke
"$S" "$r" --base no-such-ref >/dev/null 2>&1
eq "bad base ref rc" "$?" 2

"$S" "$tmp/does-not-exist" >/dev/null 2>&1
eq "missing dir rc" "$?" 2
"$S" >/dev/null 2>&1
eq "no args rc" "$?" 2
mkdir "$tmp/plain"
printf 'PIR end gate: `bash gate.sh`\n' >"$tmp/plain/AGENTS.md"
"$S" "$tmp/plain" >/dev/null 2>&1
eq "not a git repo rc" "$?" 3

echo "regression-gate.test: pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
