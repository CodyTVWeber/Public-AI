import { detectCi, detectClaude, detectTemplates } from "./detect_claude.mjs";
import { detectCommands } from "./detect_commands.mjs";
import { detectConflicts } from "./detect_conflicts.mjs";
import { detectDebt } from "./detect_debt.mjs";
import { detectGit } from "./detect_git.mjs";
import { recommend } from "./detect_recommend.mjs";
import { detectMonorepo, detectStacks, languageCounts } from "./detect_stacks.mjs";
import { detectHookSystems, detectLinters, looseEslintRules } from "./detect_tooling.mjs";
import { probeVisibility } from "./detect_visibility.mjs";
import { Repo } from "./repo.mjs";
import { isDir, print, printErr, runMain } from "./util.mjs";

const NOT_A_DIRECTORY = 3;
const USAGE = `Usage: detect-repo.sh <target> [--probe-visibility] [-h|--help]

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
`;

function parse(argv) {
  let probe = false;
  let target = null;
  for (const arg of argv) {
    if (arg === "--probe-visibility") probe = true;
    else if (arg.startsWith("-")) return [null, false];
    else target = arg;
  }
  return [target, probe];
}

export function buildProfile(repo, probe) {
  const git = detectGit(repo);
  const claude = detectClaude(repo);
  const linters = detectLinters(repo);
  const parts = {
    target: repo.root, git, stacks: detectStacks(repo), languages: languageCounts(repo),
    monorepo: detectMonorepo(repo), linters, commands: detectCommands(repo),
    hook_systems: detectHookSystems(repo), claude, ci: detectCi(repo), templates: detectTemplates(repo),
    visibility: probe ? probeVisibility(repo.root, git.forge) : "unknown",
    legacy_debt: detectDebt(repo), eslint_loose: looseEslintRules(repo, linters),
    doc_text: ["AGENTS.md", "CLAUDE.md"].filter((name) => repo.has(name)).map((name) => repo.read(name)),
  };
  parts.conflicts = detectConflicts(repo, parts);
  parts.recommend = recommend(parts);
  delete parts.eslint_loose;
  delete parts.doc_text;
  return parts;
}

function summarize(profile) {
  const rec = profile.recommend;
  const stacks = profile.stacks.map((stack) => stack.name).join(",") || "none";
  printErr("detect-repo: " + profile.target);
  printErr("  forge " + profile.git.forge + ", stacks " + stacks + ", ci " + profile.ci.provider + ", visibility " + profile.visibility);
  printErr("  recommend " + rec.profile + " " + rec.flags.map((item) => item.flag).join(" "));
  for (const question of rec.questions) printErr("  ask: " + question.ask);
}

export function main(argv) {
  if (argv.includes("-h") || argv.includes("--help")) {
    print(USAGE, 1, "");
    return 0;
  }
  const [target, probe] = parse(argv);
  if (target === null) {
    printErr(USAGE, "");
    return 2;
  }
  if (!isDir(target)) {
    printErr("detect-repo: not a directory: " + target);
    return NOT_A_DIRECTORY;
  }
  const profile = buildProfile(new Repo(target), probe);
  print(JSON.stringify(profile, null, 2));
  summarize(profile);
  return 0;
}

runMain(import.meta.url, main);
