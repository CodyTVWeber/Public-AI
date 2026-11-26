import fs from "node:fs";
import path from "node:path";
import { fnmatch, GIT_TIMEOUT_MS, lexists, realpath, run } from "./util.mjs";

const SKIP_DIRS = new Set([".git", "node_modules", "vendor", "dist", "build", "target", ".venv", "venv", "__pycache__",
  ".gradle", ".idea", ".next", "coverage"]);
const MAX_READ_BYTES = 2000000;

export function runGit(root, args) {
  const result = run("git", ["-C", root, ...args], { timeout: GIT_TIMEOUT_MS });
  return result && result.status === 0 ? result.stdout : null;
}

function walkFiles(root) {
  const found = [];
  const visit = (dir, prefix) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory() && !SKIP_DIRS.has(entry.name)) visit(path.join(dir, entry.name), prefix + entry.name + "/");
      else if (!entry.isDirectory()) found.push(prefix + entry.name);
    }
  };
  visit(root, "");
  return found.sort();
}

export class Repo {
  constructor(root) {
    this.root = realpath(root);
    const listing = runGit(this.root, ["ls-files", "-z", "-co", "--exclude-standard"]);
    this.isGit = runGit(this.root, ["rev-parse", "--is-inside-work-tree"]) !== null;
    const names = listing ? listing.split("\0") : walkFiles(this.root);
    this.files = names.filter((name) => name && lexists(this.path(name))).sort();
  }

  path(rel) {
    return path.join(this.root, rel);
  }

  has(rel) {
    return lexists(this.path(rel));
  }

  read(rel) {
    try {
      const data = fs.readFileSync(this.path(rel));
      return data.subarray(0, MAX_READ_BYTES).toString("utf8");
    } catch {
      return "";
    }
  }

  json(rel) {
    try {
      const data = JSON.parse(this.read(rel));
      return data && typeof data === "object" ? data : {};
    } catch {
      return {};
    }
  }

  match(pattern) {
    return this.files.filter((name) => fnmatch(name, pattern));
  }

  named(basename, maxDepth = 3) {
    return this.files.filter((name) => path.basename(name) === basename && name.split("/").length - 1 < maxDepth);
  }

  git(...args) {
    return runGit(this.root, args);
  }
}
