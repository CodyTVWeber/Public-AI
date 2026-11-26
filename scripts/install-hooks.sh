#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/install-hooks.sh [-h|--help]

Installs git hooks (once per clone):
  pre-commit   scripts/check-privacy.sh            (staged content and file names), then
               scripts/clean-code/check-clean-code.sh when present, else
               skills/setup-repo/assets/scripts/check-clean-code.sh (the canonical copy; it also
               runs the code-quality analyzer in --staged mode), then
               scripts/lint/check-languages.sh --staged when present (Bash or JavaScript only)
  commit-msg   scripts/check-privacy.sh --message  (the commit message)
  pre-push     scripts/check-privacy.sh --range auto (added lines, names, messages and binaries of the
               commits being pushed; blocks on findings), then the app, support, and docs MR size checks
               (check-mr-size-app.sh, check-mr-size-support.sh, check-mr-size-docs.sh beside
               scripts/clean-code/check-mr-size.sh when that tree exists, else under
               skills/setup-repo/assets/scripts/; each blocks on exit 1)
When <git-dir>/info/privacy-patterns exists, each hook sets PRIVACY_REQUIRE_PATTERNS=1 so deleting it blocks.
Warns when core.hooksPath is set: hooks install into that directory instead of .git/hooks, and every
repo sharing the path runs them.
A pre-existing hook that this script did not write (and that is not the legacy one-line privacy hook) is saved once as <name>.bak and still runs
after the privacy check. If <name>.bak already exists too, nothing is overwritten (exit 3).
Re-running is safe. Hooks are a backstop; the approval gate in AGENTS.md still applies.
Exit: 0 installed, 2 usage, 3 precondition failed
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "install-hooks: not a git repo" >&2; exit 3; }
cd "$root"
[ -f scripts/check-privacy.sh ] || { echo "install-hooks: scripts/check-privacy.sh missing" >&2; exit 3; }
hooks_dir="$(git rev-parse --git-path hooks)"
mkdir -p "$hooks_dir"
hooks_path_cfg="$(git config core.hooksPath || true)"
[ -z "$hooks_path_cfg" ] || echo "install-hooks: warning: core.hooksPath is set to $hooks_path_cfg; hooks go there, not to .git/hooks, and run for every repo sharing that path" >&2
require=""
[ ! -f "$(git rev-parse --git-path info/privacy-patterns)" ] || require="export PRIVACY_REQUIRE_PATTERNS=1"

MARK='# managed-by: scripts/install-hooks.sh'

install_hook() {
  local name="$1" body="$2" path="$hooks_dir/$1"
  if [ -e "$path" ] && ! grep -Fq "$MARK" "$path" && ! grep -Fq 'scripts/check-privacy.sh' "$path"; then
    if [ -e "$path.bak" ]; then
      echo "install-hooks: foreign $name hook exists and $name.bak is taken; move one aside" >&2
      exit 3
    fi
    cp -p "$path" "$path.bak"
    echo "backed up existing $name hook to $path.bak (still runs after the checks)"
  fi
  cat > "$path" <<HOOK
#!/usr/bin/env bash
$MARK
root="\$(git rev-parse --show-toplevel)"
$require
$body
[ -x "\$0.bak" ] && exec "\$0.bak" "\$@"
exit 0
HOOK
  chmod +x "$path"
  echo "installed $path"
}

PRE_COMMIT_BODY='"$root/scripts/check-privacy.sh" || exit $?
clean_code="$root/scripts/clean-code/check-clean-code.sh"
[ -x "$clean_code" ] || clean_code="$root/skills/setup-repo/assets/scripts/check-clean-code.sh"
[ -x "$clean_code" ] && { "$clean_code" || exit $?; }
languages="$root/scripts/lint/check-languages.sh"
[ -x "$languages" ] && { "$languages" --staged || exit $?; }'
COMMIT_MSG_BODY='"$root/scripts/check-privacy.sh" --message "$1" || exit $?'
PRE_PUSH_BODY='"$root/scripts/check-privacy.sh" --range auto || exit $?
size_dir="$root/scripts/clean-code"
[ -x "$size_dir/check-mr-size.sh" ] || size_dir="$root/skills/setup-repo/assets/scripts"
ran=0
for name in app support docs; do
  one="$size_dir/check-mr-size-$name.sh"
  [ -x "$one" ] || continue
  ran=1
  "$one"
  [ $? -eq 1 ] && exit 1
done
if [ "$ran" -eq 0 ] && [ -x "$size_dir/check-mr-size.sh" ]; then
  "$size_dir/check-mr-size.sh"
  [ $? -eq 1 ] && exit 1
fi'

chmod +x scripts/check-privacy.sh
install_hook pre-commit "$PRE_COMMIT_BODY"
install_hook commit-msg "$COMMIT_MSG_BODY"
install_hook pre-push "$PRE_PUSH_BODY"
