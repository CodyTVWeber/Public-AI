import path from "node:path";
import { isDir, isExecutable } from "./util.mjs";
import { fileHas, result } from "./verify_common.mjs";

const HOOK_NAMES = ["pre-commit", "pre-push"];
const CALL = "scripts/clean-code";

function checkGithooks(root, repo) {
  const hooksPath = (repo.git("config", "--local", "--get", "core.hooksPath") || "").trim();
  if (hooksPath !== ".githooks") return result("git-hooks", "fail", "core.hooksPath is '" + hooksPath + "', expected .githooks");
  const bad = HOOK_NAMES.filter((name) => {
    const file = path.join(root, ".githooks", name);
    return !isExecutable(file) || !fileHas(file, CALL);
  });
  if (bad.length) return result("git-hooks", "fail", ".githooks hooks missing or not calling scripts/clean-code: " + bad.join(", "));
  return result("git-hooks", "pass", "core.hooksPath=.githooks with pre-commit and pre-push");
}

function checkHusky(root) {
  const bad = HOOK_NAMES.filter((name) => !fileHas(path.join(root, ".husky", name), CALL));
  if (bad.length) return result("git-hooks", "fail", ".husky hooks not calling scripts/clean-code: " + bad.join(", "));
  return result("git-hooks", "pass", "husky hooks call scripts/clean-code");
}

function checkNative(root, repo) {
  const hooksDir = (repo.git("rev-parse", "--git-path", "hooks") || ".git/hooks").trim();
  const base = hooksDir.startsWith("/") ? hooksDir : path.join(root, hooksDir);
  const bad = HOOK_NAMES.filter((name) => !fileHas(path.join(base, name), CALL));
  if (bad.length) return result("git-hooks", "fail", "git hooks not calling scripts/clean-code: " + bad.join(", "));
  return result("git-hooks", "pass", "native git hooks call scripts/clean-code");
}

function inferHooksVia(root, repo) {
  if ((repo.git("config", "--local", "--get", "core.hooksPath") || "").trim() === ".githooks") return "githooks";
  return isDir(path.join(root, ".husky")) ? "husky" : "native";
}

export function checkGitHooks(root, repo, manifest) {
  const via = manifest ? manifest.hooks_via : inferHooksVia(root, repo);
  if (manifest && !manifest.features.includes("git-hooks")) return result("git-hooks", "skip", "git-hooks not in the install record");
  if (["lefthook", "precommit", "none"].includes(via)) {
    return result("git-hooks", "skip", "hooks-via " + via + ": wired by the repo's own hook setup, not verified");
  }
  const checks = { githooks: () => checkGithooks(root, repo), husky: () => checkHusky(root), native: () => checkNative(root, repo) };
  return checks[via]();
}
