#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { nextPatch } from "../lib/version.mjs";

const BUMP_PREFIX = "chore: bump public-ai-sync";
const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const PKG = join(ROOT, "packages", "public-ai-sync", "package.json");
const DRY = "--dry-run";

try {
  main(process.argv.slice(2));
} catch (err) {
  process.stderr.write(`public-ai-sync: ${err.message}\n`);
  process.exit(1);
}

function main(argv) {
  if (lastSubject().startsWith(BUMP_PREFIX)) {
    process.stdout.write("public-ai-sync: skip bump (already a bump commit)\n");
    return;
  }
  if (argv.includes(DRY)) printDryRun();
  else applyBump();
}

function applyBump() {
  const pkg = readPkg();
  pkg.version = nextPatch(pkg.version);
  writePkg(pkg);
  commitTag(pkg.version);
  publish();
}

function printDryRun() {
  const next = nextPatch(readPkg().version);
  process.stdout.write(`public-ai-sync: next version ${next}\n`);
  writePublishPlan();
}

function commitTag(version) {
  configureGit();
  git(["add", "--", "packages/public-ai-sync/package.json"]);
  git(["commit", "-m", `${BUMP_PREFIX} ${version}`]);
  git(["tag", `public-ai-sync-v${version}`]);
  git(["push", "origin", "HEAD"]);
  git(["push", "origin", `public-ai-sync-v${version}`]);
}

function configureGit() {
  const actor = process.env.GITHUB_ACTOR || "github-actions";
  git(["config", "user.name", actor]);
  git(["config", "user.email", `${actor}@users.noreply.github.com`]);
}

function publish() {
  writePublishPlan();
  if (!process.env.NPM_TOKEN) return;
  const result = spawnSync("npm", ["publish", "--access", "public"], {
    cwd: dirname(PKG),
    encoding: "utf8",
    env: process.env,
  });
  if (result.status !== 0) throw new Error((result.stderr || "npm publish failed").trim());
}

function writePublishPlan() {
  if (!process.env.NPM_TOKEN) {
    process.stdout.write("public-ai-sync: skip npm publish (NPM_TOKEN unset)\n");
  }
}

function lastSubject() {
  return git(["log", "-1", "--pretty=%s"]);
}

function readPkg() {
  return JSON.parse(readFileSync(PKG, "utf8"));
}

function writePkg(pkg) {
  writeFileSync(PKG, `${JSON.stringify(pkg, null, 2)}\n`);
}

function git(args) {
  const result = spawnSync("git", ["-C", ROOT, ...args], { encoding: "utf8" });
  if (result.status !== 0) throw new Error((result.stderr || result.stdout || "git failed").trim());
  return result.stdout.trim();
}
