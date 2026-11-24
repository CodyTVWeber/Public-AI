PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1" >&2; [ -z "${2:-}" ] || printf '      %s\n' "$2" >&2; }

assert_rc() { [ "$2" -eq "$3" ] && ok || bad "$1" "expected rc $2, got $3"; }
assert_eq() { [ "$2" = "$3" ] && ok || bad "$1" "expected '$2', got '$3'"; }
assert_contains() { case "$2" in *"$3"*) ok ;; *) bad "$1" "missing '$3' in: ${2:0:300}" ;; esac; }
assert_not_contains() { case "$2" in *"$3"*) bad "$1" "unexpected '$3' in: ${2:0:300}" ;; *) ok ;; esac; }

new_tmp() {
  TMPROOT="$(mktemp -d)"
  trap 'rm -rf "$TMPROOT"' EXIT
}

new_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.name tester
  git -C "$dir" config user.email tester.example
  git -C "$dir" config commit.gpgsign false
}

finish() {
  printf '%s: %d passed, %d failed\n' "$(basename "$0")" "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
