import fs from "node:fs";
import path from "node:path";
import { print, printErr, realpath, runMain } from "./util.mjs";
import { runChecks } from "./verify_checks.mjs";
import { isLocal } from "./verify_common.mjs";

const NOT_A_REPO = 3;
const USAGE = `Usage: verify-repo.sh <target> [-h|--help]

Checks that the AI guardrails installed in <target> are live. Reads .claude/ai-guardrails.json, or
.git/info/local-guardrails.json for the local profile (written by bootstrap.sh), to know what was installed;
without it, infers from what exists.
  scripts       analyzer, guards, scanner present and executable
  git-hooks     core.hooksPath=.githooks, husky or native hooks call scripts/clean-code
                (lefthook, pre-commit framework and none are wired by hand: skipped)
  settings      .claude/settings.json (local profile: settings.local.json) is valid JSON and registers the expected hooks
  hook-scripts  every registered $CLAUDE_PROJECT_DIR script exists and is executable
  analyzer      a seeded file with a comment exits 1, then 0 once clean (runs in a temp repo)
  post-git      post-git-check.sh stays silent on a non-git command
  skills        .claude/skills links resolve
  ci            the guardrails job file exists when ci was installed
  agents-doc    the AI guardrails section exists when agents-doc was installed (local: .git/info/local-guardrails.md)
  drift         installed files against the record and the source: changed-upstream, modified-locally and removed-upstream warn, missing fails
  local-clean   local profile only: no installed path shows in git status
Stdout: JSON {ok, target, installed_record, mode, drift:[{path, status: changed-upstream|modified-locally|removed-upstream|missing}],
  checks:[{id, status: pass|warn|fail|skip, detail}], failures}
Exit: 0 no failures, 1 at least one failure, 2 usage, 3 target is not a git repo`;

export function main(argv) {
  if (argv.includes("-h") || argv.includes("--help")) {
    print(USAGE);
    return 0;
  }
  if (argv.length !== 1 || argv[0].startsWith("-")) {
    printErr(USAGE);
    return 2;
  }
  const root = realpath(argv[0]);
  if (!fs.existsSync(path.join(root, ".git"))) {
    printErr("verify-repo: not a git repo: " + argv[0]);
    return NOT_A_REPO;
  }
  const [checks, [manifest, drift]] = runChecks(root);
  const failures = checks.filter((check) => check.status === "fail");
  print(JSON.stringify({ ok: failures.length === 0, target: root, installed_record: manifest !== null,
    mode: isLocal(manifest) ? "local" : "standard", drift, checks, failures: failures.length }, null, 2));
  for (const check of checks) printErr("  " + check.status.padEnd(4) + " " + check.id + ": " + check.detail);
  return failures.length ? 1 : 0;
}

runMain(import.meta.url, main);
