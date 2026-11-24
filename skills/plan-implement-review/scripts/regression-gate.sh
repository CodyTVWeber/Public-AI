#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: regression-gate.sh <repo-dir> [--base REF] [--discover-only]
  Finds the repo's regression command, refuses a dirty tree, runs it, prints JSON on stdout:
  {status: passed|failed|skipped, command, source, log_tail (last 40 lines)}
  Never pushes, merges, or posts.
Discovery order (first hit wins; this is the one canonical order for the gate):
  1. Documented gate: first `backticked` command (starting with a known runner) on a line
     mentioning "PIR end gate", "system regression" or "regression gate" in AGENTS.md,
     docs/rules/testing.md, tests/system/README.md
  2. Explicit regression target: package.json script test:system:regression | test:regression |
     regression; Makefile target regression
  3. Fallback chain, lint -> typecheck -> unit tests, joined with &&, first ecosystem found:
     package.json scripts (lint, typecheck|type-check|check-types, test) | Makefile targets
     (lint, typecheck, test; else check) | pom.xml (mvn verify) | Python config
     (ruff check, mypy, pytest when configured)
  Nothing found -> status skipped (exit 0).
--base REF  on failure, rerun in a temporary local clone at REF; each failure line also failing
            there is labelled pre_existing; adds base_status, pre_existing, new_failures, failures[]
            (pre_existing true = every failure line also fails on base: report, do not block)
--discover-only  print {command, source} and exit without running
Exit: 0 passed/skipped, 1 failed, 2 usage, 3 precondition (not a git repo, dirty tree)
USAGE
}

die() { echo "regression-gate: $1" >&2; exit "${2:-2}"; }

repo=""
base=""
discover_only=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --base) [[ $# -ge 2 ]] || die "--base needs a value"; base="$2"; shift 2 ;;
    --discover-only) discover_only=true; shift ;;
    -*) die "unknown flag: $1" ;;
    *) [[ -z "$repo" ]] || die "extra argument: $1"; repo="$1"; shift ;;
  esac
done
[[ -n "$repo" ]] || { usage; exit 2; }
[[ -d "$repo" ]] || die "not a directory: $repo"
repo="$(cd "$repo" && pwd)"

CMD=""
SOURCE=""

span_command() {
  local span
  while IFS= read -r span; do
    span="${span#\`}"
    span="${span%\`}"
    case "$span" in
      npm\ *|pnpm\ *|yarn\ *|make\ *|mvn\ *|./mvnw*|./gradlew*|gradle\ *|pytest*|python3\ *|uv\ *|poetry\ *|cargo\ *|go\ *|bash\ *|sh\ *|./*)
        printf '%s\n' "$span"; return 0 ;;
    esac
  done < <(printf '%s\n' "$1" | grep -o '`[^`]*`' || true)
  return 1
}

doc_command() {
  local f line span
  for f in AGENTS.md docs/rules/testing.md tests/system/README.md; do
    [[ -f "$repo/$f" ]] || continue
    while IFS= read -r line; do
      span="$(span_command "$line")" || continue
      CMD="$span"; SOURCE="$f"; return 0
    done < <(grep -Ei 'pir end gate|system[ -]regression|regression gate' "$repo/$f" || true)
  done
  return 1
}

pkg_runner() {
  if [[ -f "$repo/pnpm-lock.yaml" ]]; then echo "pnpm run"
  elif [[ -f "$repo/yarn.lock" ]]; then echo "yarn"
  else echo "npm run"; fi
}

pkg_has_script() {
  [[ -f "$repo/package.json" ]] || return 1
  jq -e --arg s "$1" '(.scripts // {}) | has($s)' "$repo/package.json" >/dev/null 2>&1
}

pkg_script_is_placeholder() {
  jq -e --arg s "$1" '(.scripts[$s] // "") | test("no test specified")' "$repo/package.json" >/dev/null 2>&1
}

make_has_target() {
  [[ -f "$repo/Makefile" ]] || return 1
  grep -Eq "^$1[[:space:]]*:" "$repo/Makefile"
}

explicit_command() {
  local s
  for s in test:system:regression test:regression regression; do
    if pkg_has_script "$s"; then
      CMD="$(pkg_runner) $s"; SOURCE="package.json:$s"; return 0
    fi
  done
  if make_has_target regression; then
    CMD="make regression"; SOURCE="Makefile:regression"; return 0
  fi
  return 1
}

join_and() {
  local out="" p
  for p in "$@"; do out="${out:+$out && }$p"; done
  printf '%s' "$out"
}

fallback_command() {
  local parts=() s runner

  if [[ -f "$repo/package.json" ]]; then
    runner="$(pkg_runner)"
    pkg_has_script lint && parts+=("$runner lint")
    for s in typecheck type-check check-types; do
      if pkg_has_script "$s"; then parts+=("$runner $s"); break; fi
    done
    if pkg_has_script test && ! pkg_script_is_placeholder test; then parts+=("$runner test"); fi
    if [[ ${#parts[@]} -gt 0 ]]; then
      CMD="$(join_and "${parts[@]}")"; SOURCE="package.json"; return 0
    fi
  fi

  if [[ -f "$repo/Makefile" ]]; then
    for s in lint typecheck test; do
      make_has_target "$s" && parts+=("make $s")
    done
    if [[ ${#parts[@]} -eq 0 ]] && make_has_target check; then parts+=("make check"); fi
    if [[ ${#parts[@]} -gt 0 ]]; then
      CMD="$(join_and "${parts[@]}")"; SOURCE="Makefile"; return 0
    fi
  fi

  if [[ -f "$repo/pom.xml" ]]; then
    if [[ -x "$repo/mvnw" ]]; then CMD="./mvnw -B verify"; else CMD="mvn -B verify"; fi
    SOURCE="pom.xml"; return 0
  fi

  if [[ -f "$repo/pyproject.toml" || -f "$repo/pytest.ini" || -f "$repo/setup.cfg" || -f "$repo/ruff.toml" || -f "$repo/mypy.ini" ]]; then
    if [[ -f "$repo/ruff.toml" ]] || { [[ -f "$repo/pyproject.toml" ]] && grep -q '^\[tool\.ruff' "$repo/pyproject.toml"; }; then
      parts+=("ruff check .")
    fi
    if [[ -f "$repo/mypy.ini" ]] || { [[ -f "$repo/pyproject.toml" ]] && grep -q '^\[tool\.mypy' "$repo/pyproject.toml"; }; then
      parts+=("mypy .")
    fi
    if [[ -f "$repo/pytest.ini" || -d "$repo/tests" ]] || { [[ -f "$repo/pyproject.toml" ]] && grep -q '^\[tool\.pytest' "$repo/pyproject.toml"; }; then
      parts+=("pytest")
    fi
    if [[ ${#parts[@]} -gt 0 ]]; then
      CMD="$(join_and "${parts[@]}")"; SOURCE="python"; return 0
    fi
  fi
  return 1
}

doc_command || explicit_command || fallback_command || true

if [[ "$discover_only" == true ]]; then
  jq -n --arg c "$CMD" --arg s "$SOURCE" '{command: (if $c == "" then null else $c end), source: (if $s == "" then null else $s end)}'
  exit 0
fi

git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $repo" 3
[[ -z "$(git -C "$repo" status --porcelain)" ]] || die "dirty working tree; commit or stash first: $repo" 3

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
ESC="$(printf '\033')"

clean_log() {
  sed "s/${ESC}\[[0-9;]*[A-Za-z]//g" "$1" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || cat "$1"
}

failure_lines() {
  clean_log "$1" \
    | grep -E 'FAIL|ERROR|not ok|AssertionError|Error:|✗|✕' \
    | sed -E -e 's/\([0-9.]+ ?m?s\)//g' -e 's/[0-9.]+ ?m?s$//' -e 's/[[:space:]]+$//' \
    | sort -u || true
}

run_in() {
  local dir="$1" log="$2" rc=0
  (cd "$dir" && bash -c "$CMD") >"$log" 2>&1 || rc=$?
  return "$rc"
}

if [[ -z "$CMD" ]]; then
  echo "regression-gate: no regression command found; skipped" >&2
  jq -n '{status: "skipped", command: null, source: null, log_tail: ""}'
  exit 0
fi

head_log="$tmp/head.log"
rc=0
run_in "$repo" "$head_log" || rc=$?
tail_text="$(clean_log "$head_log" | tail -n 40)"

if [[ $rc -eq 0 ]]; then
  jq -n --arg c "$CMD" --arg s "$SOURCE" --arg t "$tail_text" \
    '{status: "passed", command: $c, source: $s, log_tail: $t}'
  exit 0
fi

echo "regression-gate: failed (exit $rc): $CMD" >&2

if [[ -z "$base" ]]; then
  jq -n --arg c "$CMD" --arg s "$SOURCE" --arg t "$tail_text" \
    '{status: "failed", command: $c, source: $s, log_tail: $t}'
  exit 1
fi

sha="$(git -C "$repo" rev-parse --verify --quiet "${base}^{commit}")" || die "base ref not found: $base"
git clone -q --local --no-checkout "$repo" "$tmp/base"
git -C "$tmp/base" checkout -q --detach "$sha"
[[ -d "$repo/node_modules" ]] && ln -s "$repo/node_modules" "$tmp/base/node_modules"

base_log="$tmp/base.log"
base_rc=0
run_in "$tmp/base" "$base_log" || base_rc=$?
base_status="passed"
[[ $base_rc -eq 0 ]] || base_status="failed"

failure_lines "$head_log" >"$tmp/head.fail"
failure_lines "$base_log" >"$tmp/base.fail"

failures_json="$(
  while IFS= read -r line; do
    if grep -Fxq -- "$line" "$tmp/base.fail"; then flag=true; else flag=false; fi
    jq -nc --arg l "$line" --argjson p "$flag" '{line: $l, pre_existing: $p}'
  done <"$tmp/head.fail" | jq -s '.[:40]'
)"

jq -n --arg c "$CMD" --arg s "$SOURCE" --arg t "$tail_text" --arg b "$base" \
  --arg bs "$base_status" --argjson f "$failures_json" '
  ($f | map(select(.pre_existing | not)) | length) as $new
  | {
      status: "failed", command: $c, source: $s, log_tail: $t,
      base: $b, base_status: $bs,
      pre_existing: ($bs == "failed" and ($f | length) > 0 and $new == 0),
      new_failures: $new,
      failures: $f
    }'
exit 1
