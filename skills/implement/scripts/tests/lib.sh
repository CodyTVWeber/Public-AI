export GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

tests_dir=$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)
scripts=$(cd "$tests_dir/.." && pwd)
tmp=$(cd "$(mktemp -d)" && pwd -P)
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

jcheck() {
  check "$1" "$3" "$(printf '%s' "$out" | jq -c "$2")"
}

run() {
  rc=0
  out=$("$@" 2>"$tmp/stderr") || rc=$?
  err=$(cat "$tmp/stderr")
}

finish() {
  printf '%s: pass=%s fail=%s\n' "$(basename "${BASH_SOURCE[1]}")" "$pass" "$fail"
  [ "$fail" -eq 0 ]
}

mk_repo() {
  git init -q -b main "$1"
  mkdir -p "$1/src/a" "$1/src/b"
  printf 'one\n' >"$1/src/a/a.txt"
  printf 'two\n' >"$1/src/b/b.txt"
  printf 'shared\n' >"$1/shared.txt"
  git -C "$1" add -A
  git -C "$1" commit -q -m init
  git -C "$1" checkout -q -b feat/topic
}

commit_file() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
  git -C "$1" add -A
  git -C "$1" commit -q -m "edit $2"
}

wt_count() {
  git -C "$1" worktree list --porcelain | grep -c '^worktree '
}
