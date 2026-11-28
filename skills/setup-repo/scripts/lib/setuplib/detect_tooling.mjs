import fs from "node:fs";

const LINTER_RULES = [
  ["eslint", ["eslint.config.js", "eslint.config.mjs", "eslint.config.cjs", "eslint.config.ts", ".eslintrc",
    ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json", ".eslintrc.yml", ".eslintrc.yaml"]],
  ["prettier", [".prettierrc", ".prettierrc.json", ".prettierrc.js", ".prettierrc.yml", "prettier.config.js"]],
  ["biome", ["biome.json", "biome.jsonc"]],
  ["detekt", ["detekt.yml", "config/detekt/detekt.yml", "detekt-config.yml"]],
  ["ktlint", [".ktlint", ".editorconfig-ktlint"]],
  ["checkstyle", ["checkstyle.xml", "config/checkstyle/checkstyle.xml"]],
  ["ruff", ["ruff.toml", ".ruff.toml"]],
  ["flake8", [".flake8"]],
  ["pylint", [".pylintrc", "pylintrc"]],
  ["golangci", [".golangci.yml", ".golangci.yaml", ".golangci.toml"]],
  ["rubocop", [".rubocop.yml"]],
  ["sonar", ["sonar-project.properties"]],
];
const PYPROJECT_SECTIONS = [["ruff", "[tool.ruff"], ["black", "[tool.black"], ["pylint", "[tool.pylint"], ["flake8", "[flake8]"]];
const PACKAGE_DEPENDENCIES = ["eslint", "prettier", "@biomejs/biome"];
const DEPENDENCY_NAMES = { "@biomejs/biome": "biome" };
const HOOK_FILES = [[".husky", "husky"], ["lefthook.yml", "lefthook"], ["lefthook.yaml", "lefthook"],
  [".lefthook.yml", "lefthook"], [".pre-commit-config.yaml", "pre-commit"]];
const HOOK_NAMES = ["pre-commit", "pre-push", "commit-msg", "prepare-commit-msg", "post-commit", "post-merge"];
const BUILD_FILE_PATTERNS = ["build.gradle", "build.gradle.kts", "*/build.gradle", "*/build.gradle.kts", "pom.xml", "*/pom.xml"];
const BUILD_FILE_LINTERS = ["detekt", "ktlint", "checkstyle"];
const OWN_MARKER = "managed-by: setup-repo";
const WIRED_MARKERS = ["scripts/clean-code", "scripts/check-privacy.sh"];
const RULE_WINDOW = 120;
const MAX_RULES = [["max-params", 3], ["max-depth", 3], ["max-lines-per-function", 40]];
const RULE_NUMBER = /(?:max\s*:\s*|,\s*)(\d+)/;

function packageDependencies(repo) {
  const pkg = repo.has("package.json") ? repo.json("package.json") : {};
  const deps = {};
  for (const key of ["dependencies", "devDependencies"]) Object.assign(deps, pkg[key] || {});
  return [pkg, deps];
}

function buildFileLinters(repo) {
  const found = new Map();
  const names = BUILD_FILE_PATTERNS.flatMap((pattern) => repo.match(pattern));
  for (const name of names) {
    const text = repo.read(name);
    for (const linter of BUILD_FILE_LINTERS.filter((item) => text.includes(item))) {
      if (!found.has(linter)) found.set(linter, name);
    }
  }
  return found;
}

export function detectLinters(repo) {
  const found = new Map();
  const setDefault = (key, value) => found.has(key) || found.set(key, value);
  for (const [name, files] of LINTER_RULES) {
    const hits = files.filter((item) => repo.has(item));
    if (hits.length) found.set(name, hits[0]);
  }
  for (const [linter, evidence] of buildFileLinters(repo)) setDefault(linter, evidence);
  const pyproject = repo.has("pyproject.toml") ? repo.read("pyproject.toml") : "";
  for (const [name, section] of PYPROJECT_SECTIONS) if (pyproject.includes(section)) setDefault(name, "pyproject.toml");
  const [pkg, deps] = packageDependencies(repo);
  for (const dep of PACKAGE_DEPENDENCIES) if (dep in deps) setDefault(DEPENDENCY_NAMES[dep] ?? dep, "package.json");
  if ("eslintConfig" in pkg) setDefault("eslint", "package.json");
  return [...found.entries()].sort(([a], [b]) => (a < b ? -1 : 1)).map(([name, evidence]) => ({ name, evidence }));
}

function classifyHook(text) {
  if (text.includes(OWN_MARKER)) return "own";
  return WIRED_MARKERS.some((marker) => text.includes(marker)) ? "wired" : "foreign";
}

function readHook(base, name) {
  try {
    return fs.readFileSync(base + "/" + name, "utf8");
  } catch {
    return null;
  }
}

function nativeHooks(repo) {
  const hooksDir = (repo.git("rev-parse", "--git-path", "hooks") || "").trim();
  const found = { foreign: [], wired: [], own: [] };
  if (!hooksDir) return found;
  const base = hooksDir.startsWith("/") ? hooksDir : repo.path(hooksDir);
  for (const name of HOOK_NAMES) {
    const text = readHook(base, name);
    if (text !== null) found[classifyHook(text)].push(name);
  }
  return found;
}

export function detectHookSystems(repo) {
  const systems = [];
  const hooksPath = (repo.git("config", "--local", "--get", "core.hooksPath") || "").trim();
  if (hooksPath) systems.push({ name: "core.hooksPath", detail: hooksPath });
  if (repo.has(".githooks")) systems.push({ name: "githooks", detail: ".githooks" });
  for (const [item, label] of HOOK_FILES) if (repo.has(item)) systems.push({ name: label, detail: item });
  const [, deps] = packageDependencies(repo);
  if ("simple-git-hooks" in deps || repo.has(".simple-git-hooks.json")) {
    systems.push({ name: "simple-git-hooks", detail: "package.json" });
  }
  const found = nativeHooks(repo);
  for (const [kind, label] of [["foreign", "native"], ["wired", "native-wired"], ["own", "native-own"]]) {
    if (found[kind].length) systems.push({ name: label, detail: found[kind].join(",") });
  }
  return systems;
}

export function looseEslintRules(repo, linters) {
  const config = (linters.find((item) => item.name === "eslint") ?? {}).evidence;
  if (!config || config === "package.json") return [];
  const text = repo.read(config);
  const loose = [];
  for (const [rule, limit] of MAX_RULES) {
    const index = text.indexOf(rule);
    const number = index >= 0 ? RULE_NUMBER.exec(text.slice(index, index + RULE_WINDOW)) : null;
    if (number && Number(number[1]) > limit) loose.push({ rule, configured: Number(number[1]), limit, path: config });
  }
  return loose;
}
