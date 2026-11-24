export GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset PIR_FORGE

tests_dir=$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)
scripts=$(cd "$tests_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
real_git=$(command -v git)
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
  local dir=$1 url=$2
  git init -q --bare -b main "$dir/origin.git"
  git init -q -b main "$dir/work"
  printf 'one\n' >"$dir/work/a.txt"
  git -C "$dir/work" add a.txt
  git -C "$dir/work" commit -q -m init
  git -C "$dir/work" remote add origin "$url"
  git -C "$dir/work" config "url.$dir/origin.git.insteadOf" "$url"
  git -C "$dir/work" push -q origin main
  git -C "$dir/work" fetch -q origin
}

push_from_other_clone() {
  local dir=$1 file=$2
  rm -rf "$dir/other"
  git clone -q "$dir/origin.git" "$dir/other"
  printf 'x\n' >"$dir/other/$file"
  git -C "$dir/other" add "$file"
  git -C "$dir/other" commit -q -m "add $file"
  git -C "$dir/other" push -q origin main
}

stub_bin() {
  mkdir -p "$tmp/bin"
  stubs="$tmp/stubs"
  mkdir -p "$stubs"
  : >"$stubs/calls.log"
  export STUBS=$stubs
  export PATH="$tmp/bin:$PATH"
}

no_mutations() {
  if grep -Eq 'POST|PUT|PATCH|DELETE|--method| create | merge | comment | note ' "$stubs/calls.log"; then
    fail=$((fail + 1))
    printf 'FAIL %s: mutating call seen\n' "$1" >&2
    cat "$stubs/calls.log" >&2
  else
    pass=$((pass + 1))
  fi
}

make_stub_clis() {
  stub_bin
  cat >"$tmp/bin/glab" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUBS/calls.log"
if [ -f "$STUBS/cli.fail" ]; then
  echo "auth error" >&2
  exit 1
fi
case "$*" in
  *merge_requests/*/discussions*) cat "$STUBS/discussions.json" ;;
  *pipelines/*/jobs*) cat "$STUBS/jobs.json" ;;
  *jobs/*/trace*) cat "$STUBS/trace.txt" ;;
  *merge_requests/[0-9]*) cat "$STUBS/mr.json" ;;
  *merge_requests\?*) cat "$STUBS/mr_list.json" ;;
  *)
    echo "unexpected: $*" >&2
    exit 1
    ;;
esac
STUB
  cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUBS/calls.log"
if [ -f "$STUBS/cli.fail" ]; then
  echo "auth error" >&2
  exit 1
fi
case "$*" in
  "pr list"*) cat "$STUBS/gh_list.json" ;;
  "pr view"*) cat "$STUBS/gh_view.json" ;;
  "api graphql"*) cat "$STUBS/gh_graphql.json" ;;
  "api repos/"*compare*) cat "$STUBS/compare.txt" ;;
  "run view"*) cat "$STUBS/trace.txt" ;;
  *)
    echo "unexpected: $*" >&2
    exit 1
    ;;
esac
STUB
  chmod +x "$tmp/bin/glab" "$tmp/bin/gh"
}
