import path from "node:path";
import { fileURLToPath } from "node:url";
import { isExecutable, run } from "./util.mjs";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const GATE_RELATIVE = ["..", "..", "..", "..", "plan-implement-review", "scripts", "regression-gate.sh"];
const GATE_TIMEOUT_MS = 20000;
const SCRIPT_ALIASES = {
  lint: ["lint"], test: ["test"], typecheck: ["typecheck", "type-check", "check-types"], build: ["build"],
};
const PACKAGE_RUNNERS = [["pnpm-lock.yaml", "pnpm run"], ["yarn.lock", "yarn"], ["bun.lockb", "bun run"], ["bun.lock", "bun run"]];
const NO_TEST = /no test specified/;

const found = (command, source) => ({ command, source });

function packageRunner(repo) {
  return (PACKAGE_RUNNERS.find(([lock]) => repo.has(lock)) ?? [null, "npm run"])[1];
}

function fromPackageJson(repo) {
  if (!repo.has("package.json")) return {};
  const scripts = repo.json("package.json").scripts || {};
  const runner = packageRunner(repo);
  const result = {};
  for (const [kind, names] of Object.entries(SCRIPT_ALIASES)) {
    const name = names.find((candidate) => candidate in scripts);
    if (name && !(kind === "test" && NO_TEST.test(String(scripts[name])))) {
      result[kind] = found(runner + " " + name, "package.json:" + name);
    }
  }
  return result;
}

function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function fromMakefile(repo) {
  if (!repo.has("Makefile")) return {};
  const text = repo.read("Makefile");
  const result = {};
  for (const [kind, names] of Object.entries(SCRIPT_ALIASES)) {
    const name = names.find((candidate) => new RegExp("^" + escapeRegex(candidate) + "[ \\t]*:", "m").test(text));
    if (name) result[kind] = found("make " + name, "Makefile:" + name);
  }
  return result;
}

function pythonCommands(repo) {
  const text = repo.has("pyproject.toml") ? repo.read("pyproject.toml") : "";
  const result = {};
  if (text.includes("[tool.ruff") || repo.has("ruff.toml")) result.lint = found("ruff check .", "python");
  if (text.includes("[tool.mypy") || repo.has("mypy.ini")) result.typecheck = found("mypy .", "python");
  if (text.includes("[tool.pytest") || repo.has("pytest.ini") || repo.has("tests")) result.test = found("pytest", "python");
  return result;
}

function ecosystemDefaults(repo) {
  const result = {};
  if (repo.has("pom.xml")) {
    const runner = repo.has("mvnw") ? "./mvnw -B" : "mvn -B";
    Object.assign(result, { test: found(runner + " verify", "pom.xml"), build: found(runner + " package", "pom.xml") });
  }
  if (repo.has("build.gradle") || repo.has("build.gradle.kts")) {
    const runner = repo.has("gradlew") ? "./gradlew" : "gradle";
    Object.assign(result, { test: found(runner + " test", "gradle"), build: found(runner + " build", "gradle") });
  }
  if (repo.has("go.mod")) {
    Object.assign(result, { lint: found("go vet ./...", "go.mod"), test: found("go test ./...", "go.mod"),
      build: found("go build ./...", "go.mod") });
  }
  if (repo.has("Cargo.toml")) {
    Object.assign(result, { test: found("cargo test", "Cargo.toml"), build: found("cargo build", "Cargo.toml") });
  }
  return result;
}

function regressionCommand(repo) {
  const gate = path.normalize(path.join(SCRIPT_DIR, ...GATE_RELATIVE));
  if (!isExecutable(gate)) return null;
  const result = run(gate, [repo.root, "--discover-only"], { timeout: GATE_TIMEOUT_MS });
  if (!result) return null;
  try {
    const data = JSON.parse(result.stdout || "{}");
    return data.command ? data : null;
  } catch {
    return null;
  }
}

export function detectCommands(repo) {
  const merged = Object.assign({}, ecosystemDefaults(repo), pythonCommands(repo), fromMakefile(repo), fromPackageJson(repo));
  const result = Object.fromEntries(Object.keys(SCRIPT_ALIASES).map((kind) => [kind, merged[kind] ?? null]));
  result.regression = regressionCommand(repo);
  return result;
}
