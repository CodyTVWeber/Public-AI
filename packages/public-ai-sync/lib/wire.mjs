import {
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  readlinkSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import { DEFAULT_PATHS } from "./config.mjs";
import { npmScripts } from "./tools.mjs";

const MERGE_TOP = "scripts";
const JSON_INDENT = 2;

export function wireConsumer(cfg) {
  const links = cfg.paths.flatMap((rel) => wirePath({ cfg, rel }));
  pruneStaleOwned(cfg, links);
  injectNpmScripts(cfg.root);
  return links;
}

function wirePath(job) {
  const src = join(job.cfg.target, job.rel);
  if (!existsSync(src)) {
    dropStaleLink(join(job.cfg.root, job.rel), job.cfg.target);
    return [];
  }
  if (job.rel === MERGE_TOP) return mergeDir(job);
  return placeLink(job, src);
}

function mergeDir(job) {
  const srcDir = join(job.cfg.target, job.rel);
  const destDir = join(job.cfg.root, job.rel);
  prepareMergeDest(destDir, job.cfg.target);
  if (!isRealDir(destDir)) return [];
  return linkChildren({ cfg: job.cfg, rel: job.rel, srcDir, destDir });
}

function prepareMergeDest(destDir, targetRoot) {
  if (isOurLink(destDir, targetRoot)) unlinkSync(destDir);
  if (!hasLstat(destDir)) mkdirSync(destDir, { recursive: true });
}

function placeLink(job, src) {
  const dest = join(job.cfg.root, job.rel);
  if (hasLstat(dest)) return refreshOrSkip({ job, src, dest });
  makeLink(dest, src);
  return [job.rel];
}

function refreshOrSkip(state) {
  if (isOurLink(state.dest, state.job.cfg.target)) {
    unlinkSync(state.dest);
    makeLink(state.dest, state.src);
    return [state.job.rel];
  }
  if (!canMerge(state)) return [];
  return linkChildren({
    cfg: state.job.cfg,
    rel: state.job.rel,
    srcDir: state.src,
    destDir: state.dest,
  });
}

function canMerge(state) {
  return underScripts(state.job.rel) && isRealDir(state.dest) && isRealDir(state.src);
}

function underScripts(rel) {
  const normalized = normalizeRel(rel);
  return normalized === MERGE_TOP || normalized.startsWith(`${MERGE_TOP}/`);
}

function linkChildren(state) {
  pruneMissingChildren({
    destDir: state.destDir,
    srcDir: state.srcDir,
    targetRoot: state.cfg.target,
  });
  return readdirSync(state.srcDir).flatMap((name) =>
    wirePath({ cfg: state.cfg, rel: join(state.rel, name) }),
  );
}

function pruneMissingChildren(job) {
  for (const name of readdirSync(job.destDir)) {
    if (existsSync(join(job.srcDir, name))) continue;
    dropStaleLink(join(job.destDir, name), job.targetRoot);
  }
}

function pruneStaleOwned(cfg, kept) {
  const keptSet = new Set(kept.map(normalizeRel));
  for (const rel of staleCandidates(cfg)) {
    if (keptSet.has(normalizeRel(rel))) continue;
    dropStaleLink(join(cfg.root, rel), cfg.target);
  }
}

function staleCandidates(cfg) {
  return [...DEFAULT_PATHS, ...cfg.paths, ...scriptChildRels(cfg.root)];
}

function scriptChildRels(root) {
  const dir = join(root, MERGE_TOP);
  if (!isRealDir(dir)) return [];
  return readdirSync(dir).map((name) => join(MERGE_TOP, name));
}

function dropStaleLink(dest, targetRoot) {
  if (isOurLink(dest, targetRoot)) unlinkSync(dest);
}

function normalizeRel(rel) {
  return String(rel).replaceAll("\\", "/");
}

function makeLink(dest, src) {
  mkdirSync(dirname(dest), { recursive: true });
  symlinkSync(relative(dirname(dest), src), dest);
}

function isOurLink(dest, targetRoot) {
  try {
    return linkResolvesInto(dest, targetRoot);
  } catch (err) {
    return missingPath(err);
  }
}

function linkResolvesInto(dest, targetRoot) {
  if (!lstatSync(dest).isSymbolicLink()) return false;
  const rel = relative(resolve(targetRoot), resolve(dirname(dest), readlinkSync(dest)));
  return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel));
}

function isRealDir(path) {
  try {
    return lstatSync(path).isDirectory();
  } catch (err) {
    return missingPath(err);
  }
}

function hasLstat(path) {
  try {
    return Boolean(lstatSync(path));
  } catch (err) {
    return missingPath(err);
  }
}

function missingPath(_err) {
  return false;
}

function injectNpmScripts(root) {
  const file = join(root, "package.json");
  const pkg = readJsonOrNull(file);
  if (!pkg) return false;
  const next = nextScripts(pkg.scripts);
  if (!next) return false;
  pkg.scripts = next;
  writeFileSync(file, `${JSON.stringify(pkg, null, JSON_INDENT)}\n`);
  return true;
}

function nextScripts(current) {
  const scripts = isPlainObject(current) ? { ...current } : {};
  let changed = false;
  for (const [name, cmd] of Object.entries(npmScripts())) {
    if (scripts[name]) continue;
    scripts[name] = cmd;
    changed = true;
  }
  return changed ? scripts : null;
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function readJsonOrNull(file) {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch (err) {
    return invalidJson(err);
  }
}

function invalidJson(_err) {
  return null;
}
