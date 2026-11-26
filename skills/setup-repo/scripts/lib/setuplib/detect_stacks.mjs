import path from "node:path";
import { truthy } from "./util.mjs";

const LOCKFILES = [["pnpm-lock.yaml", "pnpm"], ["yarn.lock", "yarn"], ["bun.lockb", "bun"], ["bun.lock", "bun"],
  ["package-lock.json", "npm"], ["npm-shrinkwrap.json", "npm"]];
const MANIFESTS = [
  ["python", ["pyproject.toml", "requirements.txt", "uv.lock", "poetry.lock", "setup.py", "Pipfile"]],
  ["go", ["go.mod"]],
  ["rust", ["Cargo.toml"]],
  ["maven", ["pom.xml"]],
  ["gradle", ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"]],
  ["ruby", ["Gemfile"]],
  ["php", ["composer.json"]],
  ["swift", ["Package.swift"]],
];
export const CODE_EXTENSIONS = new Set(["js", "jsx", "mjs", "cjs", "ts", "tsx", "py", "go", "rs", "java", "kt", "kts", "rb",
  "php", "cs", "swift", "scala", "c", "h", "cc", "cpp", "hpp"]);
const TOP_LANGUAGES = 8;
const MONOREPO_MANIFESTS = ["package.json", "pom.xml", "build.gradle", "build.gradle.kts", "go.mod",
  "pyproject.toml", "Cargo.toml", "composer.json"];
const MONOREPO_MIN_DIRS = 2;
const PACKAGE_DEPTH = 4;
const WORKSPACE_FILES = [["pnpm-workspace.yaml", "pnpm-workspace"], ["turbo.json", "turbo"], ["nx.json", "nx"],
  ["lerna.json", "lerna"]];

export function extensionOf(name) {
  return path.extname(name).replace(/^\./, "").toLowerCase();
}

export function languageCounts(repo) {
  const counts = new Map();
  for (const name of repo.files) {
    const ext = extensionOf(name);
    if (ext) counts.set(ext, (counts.get(ext) ?? 0) + 1);
  }
  return [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, TOP_LANGUAGES)
    .map(([ext, files]) => ({ ext, files }));
}

function nodeStack(repo) {
  if (!repo.has("package.json")) return null;
  const manager = (LOCKFILES.find(([lock]) => repo.has(lock)) ?? [null, null])[1];
  const evidence = ["package.json", ...LOCKFILES.map(([lock]) => lock).filter((lock) => repo.has(lock))];
  return { name: "node", evidence, package_manager: manager };
}

function manifestStacks(repo) {
  const stacks = [];
  for (const [name, manifests] of MANIFESTS) {
    const evidence = manifests.filter((item) => repo.has(item));
    if (evidence.length) stacks.push({ name, evidence });
  }
  const csproj = [...repo.match("*.csproj"), ...repo.match("*/*.csproj"), ...repo.match("*.sln")];
  if (csproj.length) stacks.push({ name: "dotnet", evidence: csproj.slice(0, 3) });
  return stacks;
}

function typescriptStack(repo) {
  const configs = repo.named("tsconfig.json");
  return configs.length ? { name: "typescript", evidence: configs.slice(0, 3) } : null;
}

function shellOnly(repo, stacks) {
  if (stacks.length) return null;
  const scripts = repo.files.filter((name) => ["sh", "bash"].includes(extensionOf(name)));
  const code = repo.files.filter((name) => CODE_EXTENSIONS.has(extensionOf(name)));
  return scripts.length && !code.length ? { name: "shell", evidence: scripts.slice(0, 3) } : null;
}

export function detectStacks(repo) {
  const stacks = [nodeStack(repo), typescriptStack(repo)].filter(Boolean);
  stacks.push(...manifestStacks(repo));
  const jvmLangs = [...new Set(repo.files.map(extensionOf).filter((ext) => ["kt", "kts", "java"].includes(ext)))].sort();
  for (const stack of stacks) if (["maven", "gradle"].includes(stack.name)) stack.languages = jvmLangs;
  const shell = shellOnly(repo, stacks);
  return shell ? [...stacks, shell] : stacks;
}

function packageDirs(repo) {
  const dirs = new Set();
  for (const manifest of MONOREPO_MANIFESTS) {
    for (const found of repo.named(manifest, PACKAGE_DEPTH)) dirs.add(path.dirname(found));
  }
  return [...dirs].sort();
}

export function detectMonorepo(repo) {
  const markers = [];
  const pkg = repo.has("package.json") ? repo.json("package.json") : {};
  if (truthy(pkg.workspaces)) markers.push("workspaces");
  markers.push(...WORKSPACE_FILES.filter(([name]) => repo.has(name)).map(([, label]) => label));
  const dirs = packageDirs(repo);
  if (dirs.length >= MONOREPO_MIN_DIRS) markers.push("multiple-manifests");
  return { is_monorepo: markers.length > 0, markers, package_dirs: markers.length ? dirs : [] };
}
