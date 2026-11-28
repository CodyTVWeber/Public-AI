import { existsSync, readFileSync } from "node:fs";
import { isAbsolute, join } from "node:path";

export const DEFAULT_SOURCE = "https://github.com/CodyTVWeber/Public-AI";
export const DEFAULT_TARGET = ".public-ai";
export const DEFAULT_REF = "main";
export const DEFAULT_PATHS = [
  "rules",
  "skills",
  "AI-setup",
  "AGENTS.md",
  "CLAUDE.md",
  "GEMINI.md",
  "PRIVACY.md",
  ".claude",
  ".func-size",
  ".mr-size",
  "scripts",
];
export const FIELD = "publicAiSync";
export const PKG_NAME = "public-ai-sync";

export function loadConfig(env = process.env) {
  const root = consumerRoot(env);
  const pkg = readPkg(join(root, "package.json"));
  const field = objectField(pkg[FIELD]);
  const source = env.PUBLIC_AI_SYNC_SOURCE || field.source || DEFAULT_SOURCE;
  const targetRel = env.PUBLIC_AI_SYNC_TARGET || field.target || DEFAULT_TARGET;
  return {
    skip: envFlag(env.PUBLIC_AI_SYNC_SKIP) || skipSelf(root, pkg),
    root,
    source: resolveSource(root, source),
    ref: env.PUBLIC_AI_SYNC_REF || field.ref || DEFAULT_REF,
    paths: splitPaths(env.PUBLIC_AI_SYNC_PATHS) || pathList(field.paths) || DEFAULT_PATHS,
    targetRel,
    target: join(root, targetRel),
  };
}

export function consumerRoot(env = process.env) {
  return env.PUBLIC_AI_SYNC_ROOT || env.INIT_CWD || env.npm_config_local_prefix || process.cwd();
}

function readPkg(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return {};
  }
}

function objectField(value) {
  if (value && typeof value === "object" && !Array.isArray(value)) return value;
  return {};
}

function pathList(value) {
  return Array.isArray(value) && value.length ? value.map(String) : null;
}

function splitPaths(raw) {
  if (!raw) return null;
  const paths = raw.split(",").map((item) => item.trim()).filter(Boolean);
  return paths.length ? paths : null;
}

function envFlag(value) {
  if (value == null || value === "") return false;
  const normalized = String(value).toLowerCase();
  return normalized === "1" || normalized === "true" || normalized === "yes";
}

function skipSelf(root, pkg) {
  if (pkg?.name === PKG_NAME) return true;
  return existsSync(join(root, "packages", PKG_NAME, "package.json")) && !pkg?.[FIELD];
}

function resolveSource(root, source) {
  if (/^[a-z]+:\/\//i.test(source) || source.startsWith("git@")) return source;
  return isAbsolute(source) ? source : join(root, source);
}
