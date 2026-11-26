#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install.sh <target-repo> [flags]
  --force           overwrite files that already exist (default: skip and report)
  --no-claude-hook  skip every Claude Code hook
  --claude-hooks L  comma list of hook groups to register (default: guard,docs-lint,analyzer,stop,post-git;
                    also: approval-gate, research-ref)
  --no-post-git     leave post-git-check.sh (PostToolUse on Bash git commands) out of the default groups
  --no-githooks     skip .githooks and core.hooksPath; the target wires scripts/clean-code/* into its own hooks
  --no-rules        skip .claude/rules/*.md for repos that hold the canonical rules themselves
  --no-doc          skip the clean-code section in AGENTS.md or CLAUDE.md
  --dry-run         write nothing; report what each step would do
  --copy SRC DEST   copy-only mode: copy SRC to DEST (relative to the target); repeatable. Installs nothing else
  --overwrite DEST  with --copy: overwrite DEST when it differs (without --force); repeatable
Core copier: installs the prebuilt clean-code rules, scripts, the code-quality analyzer
(scripts/clean-code/cleancode/), the git-command scanner (scripts/clean-code/gitscan/) and hooks into a
git repo. Idempotent. Never edits linter configs. bootstrap.sh calls it; run it directly for a bare install.
Stdout: JSON {target, dry_run, files:[{path,status}], settings, git_hooks, doc, linters}; text on stderr.
  file status: create, same, differs (kept), overwrite (--force or --overwrite); each file also reports its src
Exit: 0 ok, 2 usage
USAGE
}

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ASSETS="$SKILL_DIR/assets"
PYRUN="$SKILL_DIR/scripts/lib/pyrun.sh"
DEFAULT_GROUPS="guard,docs-lint,analyzer,stop,post-git"

copies=(); overwrites=(); target=""; force=0; githooks=1; rules=1; doc=1; dry=0; post_git=1; groups="$DEFAULT_GROUPS"
while [ $# -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    --no-claude-hook) groups="" ;;
    --claude-hooks) shift; [ $# -gt 0 ] || { usage >&2; exit 2; }; groups="$1" ;;
    --no-post-git) post_git=0 ;;
    --no-githooks) githooks=0 ;;
    --no-rules) rules=0 ;;
    --no-doc) doc=0 ;;
    --dry-run) dry=1 ;;
    --copy) [ $# -ge 3 ] || { usage >&2; exit 2; }; case "/$3/" in /../*|*/../*|//*) echo "--copy DEST must be relative and stay inside the target: $3" >&2; exit 2 ;; esac; copies+=("$2" "$3"); shift 2 ;;
    --overwrite) shift; [ $# -gt 0 ] || { usage >&2; exit 2; }; overwrites+=("$1") ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) target="$1" ;;
  esac
  shift
done
[ -n "$target" ] || { usage >&2; exit 2; }
git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo: $target" >&2; exit 2; }
target="$(cd "$target" && git rev-parse --show-toplevel)"
[ "$post_git" -eq 1 ] || groups="$(printf '%s' "$groups" | tr ',' '\n' | grep -vx 'post-git' | paste -sd, - || true)"

files_json="[]"

record() {
  files_json="$(jq -c --arg p "$1" --arg s "$2" --arg src "$3" '. + [{path:$p,status:$s,src:$src}]' <<<"$files_json")"
}

wants_overwrite() {
  local item
  for item in "${overwrites[@]+"${overwrites[@]}"}"; do
    [ "$item" = "$1" ] && return 0
  done
  return 1
}

copy_file() {
  local src="$1" dest="$2" rel status
  rel="${dest#"$target"/}"
  if [ ! -e "$dest" ]; then status=create
  elif cmp -s "$src" "$dest"; then status=same
  elif [ "$force" -eq 1 ] || wants_overwrite "$rel"; then status=overwrite
  else status=differs
  fi
  record "$rel" "$status" "$src"
  case "$status" in create|overwrite) ;; *) return 0 ;; esac
  [ "$dry" -eq 1 ] && return 0
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  [ ! -x "$src" ] || chmod +x "$dest"
}

install_copies() {
  local i
  for ((i = 0; i < ${#copies[@]}; i += 2)); do
    copy_file "${copies[i]}" "$target/${copies[i + 1]}"
  done
}

copy_dir() {
  local src_dir="$1" dest_dir="$2" pattern="$3" f
  for f in "$src_dir"/$pattern; do
    [ -f "$f" ] && copy_file "$f" "$dest_dir/$(basename "$f")"
  done
  return 0
}

install_files() {
  [ "$rules" -eq 1 ] && copy_dir "$ASSETS/rules" "$target/.claude/rules" '*.md'
  copy_dir "$ASSETS/scripts" "$target/scripts/clean-code" '*.sh'
  copy_dir "$ASSETS/scripts/cleancode" "$target/scripts/clean-code/cleancode" '*.py'
  copy_dir "$ASSETS/scripts/gitscan" "$target/scripts/clean-code/gitscan" '*.py'
  [ "$dry" -eq 1 ] || chmod +x "$target"/scripts/clean-code/*.sh 2>/dev/null || true
  return 0
}

install_githooks() {
  local current
  if [ "$githooks" -ne 1 ]; then
    git_hooks='{"status":"skipped","note":"call scripts/clean-code/check-clean-code.sh (pre-commit) and pre-push-gate.sh (pre-push) from the repo hooks"}'
    return 0
  fi
  copy_dir "$ASSETS/githooks" "$target/.githooks" '*'
  [ "$dry" -eq 1 ] || chmod +x "$target"/.githooks/* 2>/dev/null || true
  current="$(git -C "$target" config --local --get core.hooksPath || true)"
  if [ -n "$current" ] && [ "$current" != ".githooks" ]; then
    git_hooks="$(jq -nc --arg p "$current" '{status:"foreign",note:("core.hooksPath is already " + $p + ": call .githooks/pre-commit and pre-push from it")}')"
    return 0
  fi
  if [ "$current" = ".githooks" ]; then
    git_hooks='{"status":"active","note":"core.hooksPath=.githooks"}'
    return 0
  fi
  [ "$dry" -eq 1 ] || git -C "$target" config --local core.hooksPath .githooks
  git_hooks='{"status":"set","note":"core.hooksPath=.githooks"}'
}

install_settings() {
  local flags=()
  [ "$dry" -eq 1 ] && flags+=(--dry-run)
  if [ -z "$groups" ]; then
    settings='{"status":"skipped","missing":[]}'
    return 0
  fi
  settings="$("$PYRUN" setuplib.settings_merge "$target/.claude/settings.json" "$groups" "${flags[@]+"${flags[@]}"}")" || {
    echo "settings.json is not valid JSON: merge the hooks by hand" >&2
    settings='{"status":"invalid","missing":[]}'
  }
}

doc_target() {
  if [ -f "$target/AGENTS.md" ] && { [ ! -f "$target/CLAUDE.md" ] || grep -q '@AGENTS.md' "$target/CLAUDE.md"; }; then
    echo AGENTS.md
  else
    echo CLAUDE.md
  fi
}

install_doc() {
  local name
  if [ "$doc" -ne 1 ]; then
    doc_json='{"status":"skipped","path":null}'
    return 0
  fi
  name="$(doc_target)"
  if [ -f "$target/$name" ] && grep -q "## Clean code and small MRs" "$target/$name"; then
    doc_json="$(jq -nc --arg p "$name" '{status:"same",path:$p}')"
    return 0
  fi
  if [ "$dry" -ne 1 ]; then
    { [ -f "$target/$name" ] && echo; cat "$ASSETS/CLAUDE.snippet.md"; } >> "$target/$name"
  fi
  doc_json="$(jq -nc --arg p "$name" '{status:"create",path:$p}')"
}

linter_hints() {
  local hints=()
  [ -f "$target/package.json" ] && hints+=("JS/TS -> assets/lint/eslint.clean-code.js")
  { [ -f "$target/build.gradle.kts" ] || [ -f "$target/build.gradle" ] || [ -f "$target/pom.xml" ]; } && hints+=("Kotlin/Java -> assets/lint/detekt-clean-code.yml")
  { [ -f "$target/pyproject.toml" ] || [ -f "$target/requirements.txt" ]; } && hints+=("Python -> assets/lint/ruff-clean-code.toml")
  printf '%s\n' "${hints[@]+"${hints[@]}"}" | jq -Rnc '[inputs | select(length > 0)]'
}

git_hooks='{"status":"skipped","note":"copy-only"}'; settings='{"status":"skipped","missing":[]}'
doc_json='{"status":"skipped","path":null}'; linters="[]"
if [ "${#copies[@]}" -gt 0 ]; then
  install_copies
else
  install_files
  install_githooks
  install_settings
  install_doc
  linters="$(linter_hints)"
fi

jq -nc --arg t "$target" --argjson dry "$dry" --argjson files "$files_json" --argjson s "$settings" \
  --argjson g "$git_hooks" --argjson d "$doc_json" --argjson l "$linters" \
  '{target:$t,dry_run:($dry==1),files:$files,settings:$s,git_hooks:$g,doc:$d,linters:$l}'

{
  echo "setup-repo install$([ "$dry" -eq 1 ] && echo ' (dry run)'): $(jq -r '[.[] | select(.status=="create" or .status=="overwrite")] | length' <<<"$files_json") files written"
  jq -r '.[] | select(.status=="differs") | "skipped (exists, differs; use --force): " + .path' <<<"$files_json"
  jq -r '.note // empty' <<<"$git_hooks"
  jq -r '"claude hooks: " + .status' <<<"$settings"
  jq -r '"doc: " + .status + " " + (.path // "")' <<<"$doc_json"
  jq -r 'if length == 0 then "no known stack detected: pick a linter that can cap nesting, params and function length" else "linter snippets to merge by hand (SKILL.md step 7):", (.[] | "  " + .) end' <<<"$linters"
} >&2
