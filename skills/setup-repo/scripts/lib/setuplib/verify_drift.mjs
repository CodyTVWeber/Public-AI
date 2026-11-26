import fs from "node:fs";
import path from "node:path";
import { computeDrift, MISSING } from "./drift.mjs";
import { runGit } from "./repo.mjs";
import { sourceRoot } from "./sources.mjs";
import { isDir } from "./util.mjs";
import { isLocal, result } from "./verify_common.mjs";

const SETTINGS_LOCAL = ".claude/settings.local.json";
const LINK_DIR = ".claude/skills";
const STATUS_COLUMNS = 3;

export function driftOf(root, manifest) {
  return manifest && manifest.files && Object.keys(manifest.files).length ? computeDrift(root, manifest, sourceRoot()) : [];
}

export function checkDrift(drift, manifest) {
  const count = manifest && manifest.files ? Object.keys(manifest.files).length : 0;
  if (!count) return result("drift", "skip", "the install record lists no copied files");
  if (!drift.length) return result("drift", "pass", count + " installed files match the record and the source");
  const missing = drift.filter((item) => item.status === MISSING);
  const detail = drift.map((item) => item.path + " " + item.status).join("; ");
  return result("drift", missing.length ? "fail" : "warn", detail);
}

function installedPaths(root, manifest) {
  const paths = new Set([...Object.keys(manifest.files || {}), SETTINGS_LOCAL]);
  const base = path.join(root, LINK_DIR);
  if (isDir(base)) {
    for (const name of fs.readdirSync(base)) {
      if (fs.lstatSync(path.join(base, name)).isSymbolicLink()) paths.add(LINK_DIR + "/" + name);
    }
  }
  return paths;
}

function porcelainPaths(root) {
  const out = runGit(root, ["status", "--porcelain", "--untracked-files=all"]) || "";
  return out.split(/\r\n|\r|\n/).filter((line) => line.length > STATUS_COLUMNS)
    .map((line) => line.slice(STATUS_COLUMNS).split(" -> ").pop().trim().replace(/^"|"$/g, ""));
}

export function checkLocalClean(root, manifest) {
  if (!isLocal(manifest)) return result("local-clean", "skip", "not the local profile");
  const wanted = installedPaths(root, manifest);
  const shown = porcelainPaths(root).filter((item) => wanted.has(item));
  if (shown.length) return result("local-clean", "fail", "installed paths show in git status: " + shown.sort().join(", "));
  return result("local-clean", "pass", "git status lists no installed path");
}
