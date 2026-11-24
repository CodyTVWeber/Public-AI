import json
import os
import sys

from .verify_checks import run_checks

NOT_A_REPO = 3
USAGE = """Usage: verify-repo.sh <target> [-h|--help]

Checks that the AI guardrails installed in <target> are live. Reads .claude/ai-guardrails.json (written by
bootstrap.sh) to know what was installed; without it, infers from what exists.
  scripts       analyzer, guards, scanner present and executable
  git-hooks     core.hooksPath=.githooks, husky or native hooks call scripts/clean-code
                (lefthook, pre-commit framework and none are wired by hand: skipped)
  settings      .claude/settings.json is valid JSON and registers the expected hooks
  hook-scripts  every registered $CLAUDE_PROJECT_DIR script exists and is executable
  analyzer      a seeded file with a comment exits 1, then 0 once clean (runs in a temp repo)
  post-git      post-git-check.sh stays silent on a non-git command
  skills        .claude/skills links resolve
  ci            the guardrails job file exists when ci was installed
  agents-doc    the AI guardrails section exists when agents-doc was installed
Stdout: JSON {ok, target, installed_record, checks:[{id, status: pass|fail|skip, detail}], failures}
Exit: 0 no failures, 1 at least one failure, 2 usage, 3 target is not a git repo"""


def main(argv):
    if "-h" in argv or "--help" in argv:
        print(USAGE)
        return 0
    if len(argv) != 1 or argv[0].startswith("-"):
        print(USAGE, file=sys.stderr)
        return 2
    root = os.path.realpath(argv[0])
    if not os.path.exists(os.path.join(root, ".git")):
        print("verify-repo: not a git repo: " + argv[0], file=sys.stderr)
        return NOT_A_REPO
    checks, manifest = run_checks(root)
    failures = [check for check in checks if check["status"] == "fail"]
    print(json.dumps({"ok": not failures, "target": root, "installed_record": manifest is not None,
                      "checks": checks, "failures": len(failures)}, indent=2))
    for check in checks:
        print("  " + check["status"].ljust(4) + " " + check["id"] + ": " + check["detail"], file=sys.stderr)
    return 1 if failures else 0
