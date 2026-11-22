#!/usr/bin/env bash
# Install the prebuilt clean-code rules, scripts and hooks into a target git repo.
#
# Usage: install.sh <target-repo> [--force] [--no-claude-hook]
#   --force           overwrite files that already exist (default: skip and report)
#   --no-claude-hook  skip the Claude Code PreToolUse guard
#
# Idempotent. Never edits linter configs: it prints which snippet matches the detected stack.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$SKILL_DIR/assets"

target=""; force=0; claude_hook=1
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    --no-claude-hook) claude_hook=0 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) target="$arg" ;;
  esac
done
[ -z "$target" ] && { echo "usage: install.sh <target-repo> [--force] [--no-claude-hook]" >&2; exit 2; }
git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo: $target" >&2; exit 2; }
target="$(cd "$target" && git rev-parse --show-toplevel)"

installed=(); skipped=()

copy_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ "$force" -ne 1 ] && ! cmp -s "$src" "$dest"; then
    skipped+=("${dest#"$target"/}"); return
  fi
  cp "$src" "$dest"; installed+=("${dest#"$target"/}")
}

for f in "$ASSETS"/rules/*.md; do copy_file "$f" "$target/.claude/rules/$(basename "$f")"; done
for f in "$ASSETS"/scripts/*.sh; do copy_file "$f" "$target/scripts/clean-code/$(basename "$f")"; done
for f in "$ASSETS"/githooks/*; do copy_file "$f" "$target/.githooks/$(basename "$f")"; done
chmod +x "$target"/scripts/clean-code/*.sh "$target"/.githooks/* 2>/dev/null || true

current_hooks_path="$(git -C "$target" config --local --get core.hooksPath || true)"
if [ -z "$current_hooks_path" ] || [ "$current_hooks_path" = ".githooks" ]; then
  git -C "$target" config --local core.hooksPath .githooks
  hooks_note="git hooks active (core.hooksPath=.githooks)"
else
  hooks_note="core.hooksPath is already '$current_hooks_path': call .githooks/pre-commit and pre-push from it manually"
fi

if [ "$claude_hook" -eq 1 ]; then
  python3 -I - "$target/.claude/settings.json" <<'PY'
import json, os, sys
path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)
data = json.load(open(path)) if os.path.exists(path) and os.path.getsize(path) else {}
cmd = '"$CLAUDE_PROJECT_DIR"/scripts/clean-code/claude-pre-tool-guard.sh'
entries = data.setdefault("hooks", {}).setdefault("PreToolUse", [])
already = any(h.get("command") == cmd for e in entries for h in e.get("hooks", []))
if not already:
    entries.append({"matcher": "Bash", "hooks": [{"type": "command", "command": cmd}]})
json.dump(data, open(path, "w"), indent=2)
open(path, "a").write("\n")
PY
  claude_note="Claude Code guard registered in .claude/settings.json"
else
  claude_note="Claude Code guard skipped"
fi

claude_md="$target/CLAUDE.md"
if [ -f "$claude_md" ] && grep -q "## Clean code and small MRs" "$claude_md"; then
  md_note="CLAUDE.md already has the clean-code section"
else
  { [ -f "$claude_md" ] && echo; cat "$ASSETS/CLAUDE.snippet.md"; } >> "$claude_md"
  md_note="appended clean-code section to CLAUDE.md"
fi

stacks=()
[ -f "$target/package.json" ] && stacks+=("JS/TS -> assets/lint/eslint.clean-code.js")
{ [ -f "$target/build.gradle.kts" ] || [ -f "$target/build.gradle" ] || [ -f "$target/pom.xml" ]; } && stacks+=("Kotlin/Java -> assets/lint/detekt-clean-code.yml")
{ [ -f "$target/pyproject.toml" ] || [ -f "$target/requirements.txt" ]; } && stacks+=("Python -> assets/lint/ruff-clean-code.toml")

echo "installed: ${#installed[@]} files"
[ "${#skipped[@]}" -gt 0 ] && printf 'skipped (exist, differ; use --force): %s\n' "${skipped[*]}"
echo "$hooks_note"
echo "$claude_note"
echo "$md_note"
if [ "${#stacks[@]}" -gt 0 ]; then
  echo "linter snippets to merge by hand (skill step 4):"; printf '  %s\n' "${stacks[@]}"
else
  echo "no known stack detected: pick a linter that can cap nesting, params and function length"
fi
