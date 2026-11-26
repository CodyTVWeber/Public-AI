#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
S="$HERE/run-implementer.sh"
ST="$HERE/pir-state.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass=0
fail=0
eq() { if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: want [$3] got [$2]" >&2; fi; }

tools="$tmp/tools"
mkdir -p "$tools" "$tmp/fakebin"
for t in bash jq uuidgen basename dirname cat tr mkdir mktemp mv rm sleep printf rmdir env; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" && "$p" == /* ]] && ln -sf "$p" "$tools/$t"
done

cat >"$tmp/fakebin/claude" <<'FAKE'
#!/usr/bin/env bash
echo run >>"$FAKE_LOG"
echo "$@" >>"$FAKE_LOG"
echo '{"sessionId":"sid-from-cli"}'
exit "${FAKE_EXIT:-0}"
FAKE
cp "$tmp/fakebin/claude" "$tmp/fakebin/grok"
chmod +x "$tmp/fakebin/claude" "$tmp/fakebin/grok"

export FAKE_LOG="$tmp/fake.log"
: >"$FAKE_LOG"
runs() { grep -c '^run$' "$FAKE_LOG" || true; }
withcli() { PATH="$tmp/fakebin:$tools" "$S" "$@"; }
nocli() { PATH="$tools" "$S" "$@"; }

echo "do the work" >"$tmp/prompt.md"
sd="$tmp/pir-demo"

nocli launch "$sd" "$tmp/prompt.md" nope-profile >/dev/null 2>&1
eq "unknown profile rc" "$?" 2
eq "unknown profile: no state created" "$(ls "$sd" 2>/dev/null | wc -l | tr -d ' ')" 0

nocli launch "$sd" "$tmp/prompt.md" claude-haiku >/dev/null 2>&1
eq "missing CLI rc" "$?" 127
eq "missing CLI: no state created" "$(ls "$sd" 2>/dev/null | wc -l | tr -d ' ')" 0

withcli launch "$sd" "$tmp/missing.md" claude-haiku >/dev/null 2>&1
eq "missing prompt rc" "$?" 2
withcli launch "$sd" "$tmp/prompt.md" >/dev/null 2>&1
eq "missing profile rc" "$?" 2
withcli frobnicate "$sd" "$tmp/prompt.md" claude-haiku >/dev/null 2>&1
eq "bad command rc" "$?" 2
withcli resume "$sd" "$tmp/prompt.md" claude-haiku >/dev/null 2>&1
eq "resume without session rc" "$?" 2
eq "no state after usage errors" "$(ls "$sd" 2>/dev/null | wc -l | tr -d ' ')" 0
eq "CLI never ran" "$(runs)" 0

out="$(withcli launch "$sd" "$tmp/prompt.md" claude-haiku 2>/dev/null)"
eq "launch rc" "$?" 0
eq "launch round" "$(jq -r .round <<<"$out")" 1
eq "launch model" "$(jq -r .model <<<"$out")" haiku
eq "state round" "$("$ST" get round --state-root "$sd")" 1
eq "state topic from dir" "$("$ST" get topic --state-root "$sd")" demo
eq "state implementer" "$("$ST" get implementer_id --state-root "$sd")" claude-haiku
eq "session from CLI output" "$("$ST" get session_id --state-root "$sd")" sid-from-cli
eq "json session" "$(jq -r .session_id <<<"$out")" sid-from-cli
eq "output file written" "$([[ -f "$sd/implement-round1.json" ]] && echo yes)" yes
eq "no legacy round file" "$([[ -e "$sd/round" ]] && echo yes || echo no)" no
eq "CLI ran once" "$(runs)" 1

out="$(withcli resume "$sd" "$tmp/prompt.md" claude-haiku sid-from-cli "$tmp" 2>/dev/null)"
eq "resume round" "$(jq -r .round <<<"$out")" 2
eq "resume passes session" "$(grep -c -- '--resume sid-from-cli' "$FAKE_LOG")" 1

withcli resume "$sd" "$tmp/prompt.md" nope-profile sid-from-cli >/dev/null 2>&1
eq "bad profile on resume rc" "$?" 2
eq "bad profile on resume keeps round" "$("$ST" get round --state-root "$sd")" 2

withcli resume "$sd" "$tmp/prompt.md" claude-haiku sid-from-cli "$tmp" >/dev/null 2>&1
eq "third attempt ok" "$("$ST" get round --state-root "$sd")" 3
before="$(runs)"
withcli resume "$sd" "$tmp/prompt.md" claude-haiku sid-from-cli "$tmp" >/dev/null 2>&1
eq "no 4th attempt rc" "$?" 3
eq "round stays 3" "$("$ST" get round --state-root "$sd")" 3
eq "CLI not started on exhausted" "$(runs)" "$before"

sd2="$tmp/pir-fail"
FAKE_EXIT=7 withcli launch "$sd2" "$tmp/prompt.md" claude-haiku >"$tmp/out.json" 2>/dev/null
eq "CLI failure rc" "$?" 1
eq "CLI exit code reported" "$(jq -r .exit_code "$tmp/out.json")" 7
eq "failed attempt still counted" "$("$ST" get round --state-root "$sd2")" 1

sd3="$tmp/pir-grok"
out="$(withcli launch "$sd3" "$tmp/prompt.md" grok-low 2>/dev/null)"
eq "grok launch rc" "$?" 0
eq "grok effort in state" "$("$ST" get reasoning_effort --state-root "$sd3")" low
eq "grok model" "$(jq -r .model <<<"$out")" grok-4.5
eq "grok effort flag passed" "$(grep -c -- '--reasoning-effort low' "$FAKE_LOG")" 1

sd3m="$tmp/pir-grok-medium"
out="$(withcli launch "$sd3m" "$tmp/prompt.md" grok-medium 2>/dev/null)"
eq "medium launch rc" "$?" 0
eq "medium effort in state" "$("$ST" get reasoning_effort --state-root "$sd3m")" medium
eq "medium effort flag passed" "$(grep -c -- '--reasoning-effort medium' "$FAKE_LOG")" 1

sd4="$tmp/pir-custom"
PIR_MAX_ROUNDS=1 withcli launch "$sd4" "$tmp/prompt.md" claude-haiku >/dev/null 2>&1
withcli launch "$sd4" "$tmp/prompt.md" claude-haiku >/dev/null 2>&1
eq "PIR_MAX_ROUNDS honoured" "$?" 3

echo "run-implementer.test: pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
