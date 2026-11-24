import json
import os
import sys

from .detect_claude import detect_ci, detect_claude, detect_templates
from .detect_commands import detect_commands
from .detect_conflicts import detect_conflicts
from .detect_debt import detect_debt
from .detect_git import detect_git
from .detect_recommend import recommend
from .detect_stacks import detect_monorepo, detect_stacks, language_counts
from .detect_tooling import detect_hook_systems, detect_linters, loose_eslint_rules
from .detect_visibility import probe_visibility
from .repo import Repo

NOT_A_DIRECTORY = 3
USAGE = """Usage: detect-repo.sh <target> [--probe-visibility] [-h|--help]

Read-only profile of a repo for setup-repo. Prints JSON on stdout, a short summary on stderr.
  git          {is_repo, default_branch, forge: gitlab|github|other|none, remote_slug_present, dirty, commit_count}
  stacks       [{name, evidence[], package_manager?, languages?}]: node, typescript, python, go, rust, maven,
               gradle, ruby, php, swift, dotnet, shell
  languages    top 8 file extensions with counts
  monorepo     {is_monorepo, markers[], package_dirs[]}
  linters      [{name, evidence}]
  commands     {lint, test, typecheck, build, regression}: {command, source} or null (regression comes from
               regression-gate.sh --discover-only when that script is reachable)
  hook_systems core.hooksPath, githooks, husky, lefthook, pre-commit, simple-git-hooks, native hooks
  claude       settings hook events, CLAUDE.md pointer state, AGENTS.md, rules, skills, comment rules
  ci           {provider, files[], gitlab_includes[]}   templates {gitlab_mr[], github_pr}
  visibility   public|private|unknown; unknown unless --probe-visibility (uses gh or glab when present)
  conflicts    [{id, path, detail, resolution}]
  legacy_debt  {files_over_400_lines, files_with_comment_density_high, files_scanned}
  recommend    {profile, hooks_via, flags[{flag, reason}], questions[], notes[]}
Exit: 0 ok, 2 usage, 3 target is not a directory
"""


def parse(argv):
    probe, target = False, None
    for arg in argv:
        if arg == "--probe-visibility":
            probe = True
        elif arg.startswith("-"):
            return None, False
        else:
            target = arg
    return target, probe


def build_profile(repo, probe):
    git = detect_git(repo)
    claude = detect_claude(repo)
    linters = detect_linters(repo)
    systems = detect_hook_systems(repo)
    parts = {
        "target": repo.root, "git": git, "stacks": detect_stacks(repo), "languages": language_counts(repo),
        "monorepo": detect_monorepo(repo), "linters": linters, "commands": detect_commands(repo),
        "hook_systems": systems, "claude": claude, "ci": detect_ci(repo), "templates": detect_templates(repo),
        "visibility": probe_visibility(repo.root, git["forge"]) if probe else "unknown",
        "legacy_debt": detect_debt(repo), "eslint_loose": loose_eslint_rules(repo, linters),
        "doc_text": [repo.read(name) for name in ("AGENTS.md", "CLAUDE.md") if repo.has(name)],
    }
    parts["conflicts"] = detect_conflicts(repo, parts)
    parts["recommend"] = recommend(parts)
    del parts["eslint_loose"], parts["doc_text"]
    return parts


def summarize(profile):
    rec = profile["recommend"]
    stacks = ",".join(stack["name"] for stack in profile["stacks"]) or "none"
    print("detect-repo: " + profile["target"], file=sys.stderr)
    print("  forge " + profile["git"]["forge"] + ", stacks " + stacks + ", ci " + profile["ci"]["provider"]
          + ", visibility " + profile["visibility"], file=sys.stderr)
    print("  recommend " + rec["profile"] + " " + " ".join(item["flag"] for item in rec["flags"]), file=sys.stderr)
    for question in rec["questions"]:
        print("  ask: " + question["ask"], file=sys.stderr)


def main(argv):
    if "-h" in argv or "--help" in argv:
        print(USAGE, end="")
        return 0
    target, probe = parse(argv)
    if target is None:
        print(USAGE, file=sys.stderr, end="")
        return 2
    if not os.path.isdir(target):
        print("detect-repo: not a directory: " + target, file=sys.stderr)
        return NOT_A_DIRECTORY
    profile = build_profile(Repo(target), probe)
    print(json.dumps(profile, indent=2))
    summarize(profile)
    return 0
