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
import { dirname, join, relative, resolve } from "node:path";
import { LIFECYCLE_SCRIPTS, npmScripts } from "./tools.mjs";

const MERGE_TOP = "scripts";
const JSON_INDENT = 2;

export function wireConsumer(cfg) {
  const links = cfg.paths.flatMap((rel) => wirePath({ cfg, rel }));
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
  pruneMissingChildren({ destDir, srcDir, targetRoot: job.cfg.target });
  return readdirSync(srcDir).flatMap((name) =>
    wirePath({ cfg: job.cfg, rel: join(job.rel, name) }),
  );
}

function prepareMergeDest(destDir, targetRoot) {
  if (isOurLink(destDir, targetRoot)) unlinkSync(destDir);
  if (!hasLstat(destDir)) mkdirSync(destDir, { recursive: true });
}

function pruneMissingChildren(job) {
  for (const name of readdirSync(job.destDir)) {
    if (existsSync(join(job.srcDir, name))) continue;
    dropStaleLink(join(job.destDir, name), job.targetRoot);
  }
}

function dropStaleLink(dest, targetRoot) {
  if (isOurLink(dest, targetRoot)) unlinkSync(dest);
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
  if (!isRealDir(state.dest) || !isRealDir(state.src)) return [];
  return readdirSync(state.src).flatMap((name) =>
    wirePath({ cfg: state.job.cfg, rel: join(state.job.rel, name) }),
  );
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
  const resolved = resolve(dirname(dest), readlinkSync(dest));
  const root = resolve(targetRoot);
  return resolved === root || resolved.startsWith(`${root}/`);
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
  for (const [name, cmd] of Object.entries({ ...LIFECYCLE_SCRIPTS, ...npmScripts() })) {
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
