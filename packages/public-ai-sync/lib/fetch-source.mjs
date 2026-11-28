import { cpSync, existsSync, mkdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { SyncError } from "./errors.mjs";
import { listFiles, rmIfExists } from "./fs-util.mjs";

const CLONE_DEPTH = "1";

export function materializeSource(job) {
  rmIfExists(job.staging);
  mkdirSync(job.staging, { recursive: true });
  fillStaging(job);
  assertNonEmpty(job.staging);
}

function fillStaging(job) {
  if (isLocalDir(job.cfg.source)) {
    copyListedPaths({ from: job.cfg.source, to: job.staging, paths: job.cfg.paths });
    return;
  }
  rmIfExists(job.gitDir);
  cloneGit({ source: job.cfg.source, ref: job.cfg.ref, dest: job.gitDir });
  copyListedPaths({ from: job.gitDir, to: job.staging, paths: job.cfg.paths });
}

function isLocalDir(source) {
  try {
    return existsSync(source) && statSync(source).isDirectory();
  } catch {
    return false;
  }
}

function cloneGit(spec) {
  const result = spawnSync(
    "git",
    ["clone", "--depth", CLONE_DEPTH, "--branch", spec.ref, "--", spec.source, spec.dest],
    { encoding: "utf8", env: { ...process.env, GIT_TERMINAL_PROMPT: "0" } },
  );
  if (result.status !== 0) throw new SyncError(cloneMessage(result, spec.source));
}

function cloneMessage(result, source) {
  const detail = (result.stderr || result.stdout || "git clone failed").trim().split("\n")[0];
  return `public-ai-sync: failed to fetch ${source}: ${detail}`;
}

function copyListedPaths(spec) {
  mkdirSync(spec.to, { recursive: true });
  for (const rel of spec.paths) copyOnePath({ from: spec.from, to: spec.to, rel });
}

function copyOnePath(spec) {
  const src = join(spec.from, spec.rel);
  if (!existsSync(src)) return;
  cpSync(src, join(spec.to, spec.rel), { recursive: true });
}

function assertNonEmpty(dir) {
  if (listFiles(dir).length === 0) {
    throw new SyncError("public-ai-sync: source has no files in the configured paths; left the target folder unchanged");
  }
}
