import { spawnSync } from "node:child_process";

const EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904";
const HUNK = /^@@ -\d+(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/;
const NEW_FILE_MARK = "--- /dev/null";
const TARGET_PREFIX = "+++ b/";
const MAX_OUTPUT = 1 << 30;
const DIFF_FLAGS = ["-c", "core.quotepath=off", "diff", "-U0", "--no-color", "--no-ext-diff",
  "-M", "--diff-filter=ACMR", "--src-prefix=a/", "--dst-prefix=b/"];

export class GitError extends Error {}

export class FileChange {
  constructor(lines, counts = {}) {
    Object.assign(this, { lines, added: 0, removed: 0, isNew: false }, counts);
  }

  has(line) {
    return this.lines === null || this.lines.has(line);
  }

  touches(low, high) {
    if (this.lines === null) return true;
    for (const line of this.lines) if (line >= low && line <= high) return true;
    return false;
  }

  get grows() {
    return this.isNew || this.added > this.removed;
  }
}

export function everything() {
  return new FileChange(null, { isNew: true });
}

export function git(cwd, args, stdin) {
  const env = { ...process.env, GIT_LITERAL_PATHSPECS: "1" };
  const done = spawnSync("git", ["-C", cwd, ...args], { input: stdin, encoding: "utf8", env, maxBuffer: MAX_OUTPUT });
  return [done.status === null ? 1 : done.status, done.stdout || ""];
}

function toplevel(cwd) {
  const [code, out] = git(cwd, ["rev-parse", "--show-toplevel"]);
  return code === 0 ? out.trim() : null;
}

export function requireRoot(cwd) {
  const root = toplevel(cwd);
  if (root === null) throw new GitError("not inside a git work tree: " + cwd);
  return root;
}

export function baseRef(root) {
  const [code] = git(root, ["rev-parse", "--verify", "-q", "HEAD"]);
  return code === 0 ? "HEAD" : EMPTY_TREE;
}

function addHunk(change, header) {
  const found = HUNK.exec(header);
  if (!found) return;
  const removed = parseInt(found[1] || 1, 10);
  const start = parseInt(found[2], 10);
  const count = found[3] === undefined ? 1 : parseInt(found[3], 10);
  for (let line = start; line < start + count; line++) change.lines.add(line);
  change.added += count;
  change.removed += removed;
}

function parseDiff(text) {
  const changes = new Map();
  let current = null;
  let newFile = false;
  let inHunk = false;
  for (const line of text.split("\n")) {
    if (line.startsWith("diff --git ")) {
      [current, newFile, inHunk] = [null, false, false];
    } else if (inHunk && !line.startsWith("@@")) {
      continue;
    } else if (line === NEW_FILE_MARK) {
      newFile = true;
    } else if (line.startsWith(TARGET_PREFIX)) {
      current = line.slice(TARGET_PREFIX.length).split("\t")[0];
      changes.set(current, new FileChange(new Set(), { isNew: newFile }));
    } else if (current && line.startsWith("@@")) {
      inHunk = true;
      addHunk(changes.get(current), line);
    }
  }
  return changes;
}

export function diffChanges(root, extra) {
  const [code, out] = git(root, [...DIFF_FLAGS, ...extra]);
  if (code !== 0) throw new GitError("git diff failed: " + extra.join(" "));
  return parseDiff(out);
}
