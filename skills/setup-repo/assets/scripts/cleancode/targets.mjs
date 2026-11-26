import fs from "node:fs";
import path from "node:path";
import { GitError, baseRef, diffChanges, everything, git, requireRoot } from "./gitdiff.mjs";
import { specFor } from "./languages.mjs";

const MAX_BYTES = 2_000_000;

export function fileOptions(options = {}) {
  return { skipIgnored: false, allLines: false, requireRepo: false, ...options };
}

export function readWorktree(root, file) {
  const full = path.resolve(root, file);
  try {
    const stat = fs.statSync(full);
    if (!stat.isFile() || stat.size > MAX_BYTES) return null;
    return fs.readFileSync(full, "utf8");
  } catch {
    return null;
  }
}

function readBlob(root, ref, file) {
  const [code, out] = git(root, ["show", `${ref}:${file}`]);
  return code === 0 && out.length <= MAX_BYTES ? out : null;
}

function buildTargets(changes, reader) {
  const targets = [];
  for (const file of [...changes.keys()].sort()) {
    const text = specFor(file) ? reader(file) : null;
    if (text !== null) targets.push({ path: file, text, change: changes.get(file) });
  }
  return targets;
}

export function stagedTargets(cwd) {
  const root = requireRoot(cwd);
  const changes = diffChanges(root, ["--cached", baseRef(root)]);
  return buildTargets(changes, (file) => readBlob(root, "", file));
}

function mergeBase(root, base, head = "HEAD") {
  const [code] = git(root, ["rev-parse", "--verify", "-q", base + "^{commit}"]);
  if (code !== 0) throw new GitError("unknown base: " + base);
  const [found, out] = git(root, ["merge-base", base, head]);
  return found === 0 && out.trim() ? out.trim() : base;
}

function untrackedPaths(root) {
  const [, out] = git(root, ["ls-files", "-o", "--exclude-standard", "-z"]);
  return out.split("\0").filter(Boolean);
}

function trackedChanges(root, base) {
  const reference = base === "HEAD" ? baseRef(root) : mergeBase(root, base);
  return diffChanges(root, [reference]);
}

export function trackedTargets(cwd) {
  const root = requireRoot(cwd);
  return buildTargets(trackedChanges(root, "HEAD"), (file) => readWorktree(root, file));
}

export function changedTargets(cwd, base) {
  const root = requireRoot(cwd);
  const changes = trackedChanges(root, base);
  for (const file of untrackedPaths(root)) changes.set(file, everything());
  return buildTargets(changes, (file) => readWorktree(root, file));
}

function splitRange(spec) {
  for (const dots of ["...", ".."]) {
    const at = spec.indexOf(dots);
    if (at >= 0) return [spec.slice(0, at), spec.slice(at + dots.length) || "HEAD", dots === "..."];
  }
  throw new GitError("range must look like BASE..HEAD: " + spec);
}

function verifyRef(root, ref, kind) {
  const [code] = git(root, ["rev-parse", "--verify", "-q", `${ref}^{${kind}}`]);
  if (code !== 0) throw new GitError("unknown ref: " + ref);
}

export function rangeTargets(cwd, spec) {
  const root = requireRoot(cwd);
  const [first, end, symmetric] = splitRange(spec);
  verifyRef(root, end, "commit");
  verifyRef(root, first, "tree");
  const start = symmetric ? mergeBase(root, first, end) : first;
  return buildTargets(diffChanges(root, [start, end]), (file) => readBlob(root, end, file));
}
