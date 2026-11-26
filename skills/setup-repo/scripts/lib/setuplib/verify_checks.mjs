import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { GROUPS, PROJECT_DIR } from "./hookspec.mjs";
import { gitPath, LOCAL_NOTE_RELATIVE } from "./record.mjs";
import { Repo } from "./repo.mjs";
import { isExecutable, isFile, run } from "./util.mjs";
import { CORE_SCRIPTS, fileHas, isLocal, loadManifest, result, settingsFile } from "./verify_common.mjs";
import { checkDrift, checkLocalClean, driftOf } from "./verify_drift.mjs";
import { checkGitHooks } from "./verify_git.mjs";

const CHECK_TIMEOUT_MS = 60000;
const CORE_PACKAGES = ["cleancode/cli.mjs", "gitscan/cli.mjs"];
const HOOK_GROUPS_BY_FEATURE = { "claude-hooks": ["guard", "docs-lint", "analyzer", "stop"], "post-git-hook": ["post-git"],
  "approval-gate": ["approval-gate"], "research-ref": ["research-ref"] };
const SEEDED_VIOLATION = "export const probe = 1;\n// a note\n";
const SEEDED_CLEAN = "export const probe = 1;\n";
const GIT_IDENTITY = ["-c", "user.name=probe", "-c", "user.email=probe.example", "-c", "commit.gpgsign=false"];

function checkScripts(root) {
  const base = path.join(root, "scripts", "clean-code");
  const missing = [...CORE_SCRIPTS.filter((name) => !isExecutable(path.join(base, name))),
    ...CORE_PACKAGES.filter((name) => !isFile(path.join(base, name)))];
  if (missing.length) return result("scripts", "fail", "missing or not executable in scripts/clean-code: " + missing.join(", "));
  return result("scripts", "pass", "analyzer, guards and scanner are installed");
}

function expectedCommands(manifest, registered) {
  if (manifest === null) return registered.filter((command) => command.includes("scripts/clean-code"));
  const groups = manifest.features.flatMap((feature) => HOOK_GROUPS_BY_FEATURE[feature] ?? []);
  return groups.flatMap((group) => GROUPS[group].map((spec) => spec.command));
}

function registeredCommands(settings) {
  const hooks = settings.hooks || {};
  return Object.values(hooks).flatMap((entries) => entries.flatMap((entry) => (entry.hooks ?? []).map((hook) => hook.command ?? "")));
}

function checkSettings(root, manifest) {
  const file = settingsFile(root, manifest);
  if (!isFile(file)) {
    const wanted = manifest && manifest.features.some((feature) => feature in HOOK_GROUPS_BY_FEATURE);
    return result("settings", wanted ? "fail" : "skip", "no " + path.relative(root, file));
  }
  let settings;
  try {
    settings = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    return result("settings", "fail", "settings.json is not valid JSON: " + error.message);
  }
  const registered = registeredCommands(settings);
  const missing = expectedCommands(manifest, registered).filter((command) => !registered.includes(command));
  if (missing.length) return result("settings", "fail", "hooks not registered: " + missing.join("; "));
  return result("settings", "pass", registered.length + " hook commands registered");
}

function checkHookScripts(root, manifest) {
  let commands;
  try {
    commands = registeredCommands(JSON.parse(fs.readFileSync(settingsFile(root, manifest), "utf8")));
  } catch {
    return result("hook-scripts", "skip", "no readable settings.json");
  }
  const prefix = PROJECT_DIR + "/";
  const missing = commands.filter((command) => command.startsWith(prefix))
    .map((command) => command.slice(prefix.length).split(" ")[0])
    .filter((script) => !isExecutable(path.join(root, script)));
  if (missing.length) return result("hook-scripts", "fail", "registered scripts missing or not executable: " + [...new Set(missing)].sort().join(", "));
  return result("hook-scripts", "pass", "every registered script exists and is executable");
}

function runAnalyzer(root, cwd, name) {
  const command = path.join(root, "scripts", "clean-code", "code-quality-check.sh");
  const outcome = run(command, [name], { cwd, timeout: CHECK_TIMEOUT_MS });
  return outcome ? outcome.status : null;
}

function seededAnalyzerRun(root, tmp) {
  const probe = path.join(tmp, "probe.ts");
  fs.writeFileSync(probe, SEEDED_VIOLATION);
  const dirty = runAnalyzer(root, tmp, "probe.ts");
  fs.writeFileSync(probe, SEEDED_CLEAN);
  const clean = runAnalyzer(root, tmp, "probe.ts");
  if (dirty === 1 && clean === 0) return result("analyzer", "pass", "exits 1 on a seeded comment, 0 once clean");
  return result("analyzer", "fail", "seeded violation exit " + dirty + " (want 1), clean exit " + clean + " (want 0)");
}

function checkAnalyzer(root) {
  if (!isExecutable(path.join(root, "scripts", "clean-code", "code-quality-check.sh"))) {
    return result("analyzer", "fail", "scripts/clean-code/code-quality-check.sh is missing");
  }
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "verify-"));
  try {
    run("git", ["init", "-q", tmp]);
    fs.writeFileSync(path.join(tmp, "base.ts"), "export const base = 1;\n");
    run("git", ["-C", tmp, "add", "--", "base.ts"]);
    run("git", ["-C", tmp, ...GIT_IDENTITY, "commit", "-q", "-m", "base"]);
    return seededAnalyzerRun(root, tmp);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

function checkPostGit(root) {
  const hook = path.join(root, "scripts", "clean-code", "post-git-check.sh");
  if (!isExecutable(hook)) return result("post-git", "skip", "post-git-check.sh not installed");
  const payload = JSON.stringify({ tool_name: "Bash", tool_input: { command: "ls" }, cwd: root });
  const outcome = run(hook, [], { input: payload, timeout: CHECK_TIMEOUT_MS });
  if (outcome && outcome.status === 0 && !outcome.stdout.trim()) return result("post-git", "pass", "silent on a non-git command");
  return result("post-git", "fail", "expected exit 0 and no output on `ls`, got exit " + (outcome ? outcome.status : "none"));
}

function isLink(file) {
  return fs.lstatSync(file).isSymbolicLink();
}

function checkSkills(root, manifest) {
  const base = path.join(root, ".claude", "skills");
  const links = fs.existsSync(base) ? fs.readdirSync(base).sort().map((name) => path.join(base, name)) : [];
  const dangling = links.filter((link) => isLink(link) && !fs.existsSync(link)).map((link) => path.basename(link));
  if (dangling.length) return result("skills", "fail", "dangling skill links: " + dangling.join(", "));
  if (manifest && manifest.features.includes("skills") && !links.length) {
    return result("skills", "fail", "skills are in the install record but .claude/skills is empty");
  }
  return result("skills", links.length ? "pass" : "skip", links.length + " skill links resolve");
}

function checkCi(root, manifest) {
  if (!manifest || !manifest.features.includes("ci")) return result("ci", "skip", "ci not in the install record");
  const candidates = [".gitlab/ci/ai-guardrails.yml", ".github/workflows/ai-guardrails.yml"];
  const found = candidates.filter((name) => isFile(path.join(root, name)));
  if (found.length) return result("ci", "pass", found[0]);
  return result("ci", "fail", "ci is in the install record but no guardrails job file exists");
}

function checkDoc(root, manifest) {
  if (!manifest || !manifest.features.includes("agents-doc")) return result("agents-doc", "skip", "agents-doc not in the install record");
  const names = isLocal(manifest) ? [path.relative(root, gitPath(root, LOCAL_NOTE_RELATIVE))] : ["AGENTS.md", "CLAUDE.md"];
  for (const name of names) {
    if (fileHas(path.join(root, name), "<!-- ai-guardrails:begin -->")) return result("agents-doc", "pass", name + " holds the AI guardrails section");
  }
  return result("agents-doc", "fail", "no AI guardrails section in AGENTS.md or CLAUDE.md");
}

export function runChecks(root) {
  const repo = new Repo(root);
  const manifest = loadManifest(root);
  const drift = driftOf(root, manifest);
  const checks = [checkScripts(root), checkGitHooks(root, repo, manifest), checkSettings(root, manifest),
    checkHookScripts(root, manifest), checkAnalyzer(root), checkPostGit(root), checkSkills(root, manifest),
    checkCi(root, manifest), checkDoc(root, manifest), checkDrift(drift, manifest), checkLocalClean(root, manifest)];
  return [checks, [manifest, drift]];
}
