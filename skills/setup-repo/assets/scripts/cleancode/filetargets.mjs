import fs from "node:fs";
import path from "node:path";
import { FileChange, baseRef, diffChanges, everything, git } from "./gitdiff.mjs";
import { specFor } from "./languages.mjs";
import { fileOptions, readWorktree } from "./targets.mjs";

function realpath(file) {
  try {
    return fs.realpathSync(file);
  } catch {
    return path.resolve(file);
  }
}

function isFile(file) {
  try {
    return fs.statSync(file).isFile();
  } catch {
    return false;
  }
}

function findRoot(directory) {
  let current = directory;
  while (!fs.existsSync(path.join(current, ".git"))) {
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
  return current;
}

function analyzable(paths) {
  const found = [];
  for (const file of paths) {
    const absolute = realpath(file);
    if (isFile(absolute) && specFor(absolute) !== null) found.push([file, absolute]);
  }
  return found;
}

function groupByRoot(items) {
  const roots = new Map();
  const outside = [];
  const known = new Map();
  for (const [file, absolute] of items) {
    const folder = path.dirname(absolute);
    if (!known.has(folder)) known.set(folder, findRoot(folder));
    const root = known.get(folder);
    if (root === null) outside.push([file, absolute]);
    else roots.set(root, [...(roots.get(root) || []), path.relative(root, absolute)]);
  }
  return [roots, outside];
}

function listed(root, args, stdin) {
  const [, out] = git(root, args, stdin);
  return new Set(out.split("\0").filter(Boolean));
}

function ignoredAmong(root, paths) {
  const args = ["--no-literal-pathspecs", "check-ignore", "-z", "--stdin"];
  return listed(root, args, paths.join("\0") + "\0");
}

function changesFor(root, tracked) {
  if (tracked.size === 0) return new Map();
  return diffChanges(root, [baseRef(root), "--", ...[...tracked].sort()]);
}

function rootTargets(root, paths, options) {
  const tracked = options.allLines ? new Set() : listed(root, ["ls-files", "-z", "--", ...paths]);
  let kept = paths;
  if (options.skipIgnored) {
    const hidden = ignoredAmong(root, paths);
    kept = paths.filter((file) => !hidden.has(file));
  }
  const changes = changesFor(root, tracked);
  return kept.map((file) => {
    const change = tracked.has(file) ? changes.get(file) || new FileChange(new Set()) : everything();
    return { path: file, text: readWorktree(root, file), change };
  });
}

export function fileTargets(paths, options = fileOptions()) {
  const [roots, outside] = groupByRoot(analyzable(paths));
  const found = [];
  for (const [root, relative] of roots) found.push(...rootTargets(root, relative, options));
  if (!options.requireRepo) {
    for (const [file, absolute] of outside) found.push({ path: file, text: readWorktree("/", absolute), change: everything() });
  }
  return found.filter((target) => target.text !== null);
}
