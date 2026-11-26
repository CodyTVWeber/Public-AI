import fs from "node:fs";
import path from "node:path";
import { fileHash } from "./drift.mjs";
import { sourceRoot, sourceSha } from "./sources.mjs";
import { run } from "./util.mjs";

export const STANDARD_PATH = ".claude/ai-guardrails.json";
const LOCAL_RELATIVE = "info/local-guardrails.json";
export const LOCAL_NOTE_RELATIVE = "info/local-guardrails.md";

export function gitPath(root, relative) {
  const out = run("git", ["-C", root, "rev-parse", "--git-path", relative]);
  const found = out ? out.stdout.trim() : "";
  return found.startsWith("/") ? found : path.join(root, found);
}

export function recordPath(root, local) {
  return local ? gitPath(root, LOCAL_RELATIVE) : path.join(root, STANDARD_PATH);
}

function readJsonObject(file) {
  try {
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    return data && typeof data === "object" && !Array.isArray(data) ? data : null;
  } catch {
    return null;
  }
}

export function loadRecord(root) {
  return readJsonObject(gitPath(root, LOCAL_RELATIVE)) || readJsonObject(path.join(root, STANDARD_PATH));
}

function fileEntries(ctx, previous) {
  const base = sourceRoot();
  const files = {};
  for (const [file, entry] of Object.entries((previous && previous.files) || {})) {
    if (fs.existsSync(path.join(ctx.root, file))) files[file] = entry;
  }
  for (const [file, src] of [...ctx.installed.entries()].sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))) {
    files[file] = { hash: fileHash(src), source: path.relative(base, src) };
  }
  return files;
}

export function buildRecord(ctx) {
  const previous = loadRecord(ctx.root);
  return {
    tool: "setup-repo", mode: ctx.local ? "local" : "standard", profile: ctx.options.profile, features: ctx.features,
    hooks_via: ctx.hooksVia, skills: ctx.on("skills") ? ctx.options.skills : "none",
    source_sha: sourceSha(sourceRoot()), files: fileEntries(ctx, previous),
  };
}
