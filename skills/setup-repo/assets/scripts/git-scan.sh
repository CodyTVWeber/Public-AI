#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: git-scan.sh [COMMAND] [-h|--help]

Finds git and forge commands inside a shell command line, however written: git -C d push,
env X=1 git push, sh -c "git push", chained, command substitution, heredoc bodies that run a
shell, git aliases. Reads Claude Code hook JSON on stdin (.tool_input.command, .cwd), or takes COMMAND.
Prints one tag per line:
  commit, push, merge, pull       the git subcommand runs
  commit-like                     merge, cherry-pick, revert, am, rebase -x, commit-tree, update-ref,
                                  filter-branch, fast-import, submodule foreach
  push-like                       send-pack, http-push
  mr-create                       gh pr create, glab mr create
  forge-write                     gh pr merge, glab mr merge, gh/glab api writes
  push-force                      --force, -f, +ref, --delete, --mirror on push
  ask-unknown-git                 a git subcommand that is no builtin and no known alias
  ask-dynamic                     a command word built at runtime whose words name commit, push, merge
  ask-interpreter                 text piped into a shell, inline python/perl/ruby/node/awk code, or
                                  xargs git with the subcommand on stdin, naming a commit or push
  deny:no-verify, deny:hookspath  hook bypass; hooksPath writes via git -c, git config, GIT_CONFIG_*
  deny:skip, skip-soft            CLEAN_CODE_SKIP, SKIP=, HUSKY=0
  unparsed                        the command only partly parsed
Exit: 0 tags printed (possibly none), 2 usage, 3 node missing
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -*) usage >&2; exit 2 ;;
esac
command -v node >/dev/null 2>&1 || exit 3
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec node "$here/gitscan/main.mjs" "$@"
