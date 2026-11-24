. "$here/../../../../../scripts/tests/lib.sh"
CQ="$here/../code-quality-check.sh"

fx() { mkdir -p "$(dirname "$TMPROOT/$1")"; cat > "$TMPROOT/$1"; }

rules_of() { "$CQ" --all-lines "$TMPROOT/$1" 2>/dev/null | jq -r '[.findings[].rule] | unique | join(" ")'; }

severity_of() { "$CQ" --all-lines "$TMPROOT/$1" 2>/dev/null | jq -r --arg r "$2" '[.findings[] | select(.rule == $r) | .severity] | unique | join(",")'; }

expect_rule() {
  case " $(rules_of "$2") " in *" $3 "*) ok ;; *) bad "$1" "no $3 in: $(rules_of "$2")" ;; esac
}

expect_no_rule() {
  case " $(rules_of "$2") " in *" $3 "*) bad "$1" "unexpected $3" ;; *) ok ;; esac
}

expect_clean() {
  local found
  found="$(rules_of "$2")"
  [ -z "$found" ] && ok || bad "$1" "findings: $found"
}

with_env() { env "$@"; }

make_repo() {
  new_repo "$1"
  printf 'export const base = 1;\n' > "$1/base.ts"
  git -C "$1" add -- .
  git -C "$1" commit -qm base
}

isolate_tmp() {
  export TMPDIR="$TMPROOT/logs"
  mkdir -p "$TMPDIR"
}
