import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { loadConfig } from "../../packages/public-ai-sync/lib/config.mjs";
import { sync } from "../../packages/public-ai-sync/lib/run.mjs";
import { nextPatch } from "../../packages/public-ai-sync/lib/version.mjs";
import { listFiles } from "../../packages/public-ai-sync/lib/fs-util.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const BIN = join(ROOT, "packages", "public-ai-sync", "bin", "sync.mjs");
const BUMP = join(ROOT, "packages", "public-ai-sync", "scripts", "bump.mjs");

test("local source fills the target and gitignore", () => {
  const root = seedConsumer();
  try {
    assert.equal(sync(cfgFor(root)), 0);
    assert.equal(readFileSync(join(root, ".public-ai", "AGENTS.md"), "utf8"), "agents-v1\n");
    assert.equal(readFileSync(join(root, ".public-ai", "rules", "sample.md"), "utf8"), "rule-v1\n");
    assert.equal(readFileSync(join(root, ".public-ai", "skills", "demo", "SKILL.md"), "utf8"), "skill-v1\n");
    assert.match(readFileSync(join(root, ".gitignore"), "utf8"), /^\.public-ai\/$/m);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("second sync replaces the tree", () => {
  const root = seedConsumer();
  try {
    sync(cfgFor(root));
    writeTree(join(root, "ai-source"), {
      "AGENTS.md": "agents-v2\n",
      "rules/extra.md": "extra\n",
    });
    rmSync(join(root, "ai-source", "skills"), { recursive: true, force: true });
    assert.equal(sync(cfgFor(root)), 0);
    assert.equal(readFileSync(join(root, ".public-ai", "AGENTS.md"), "utf8"), "agents-v2\n");
    assert.equal(readFileSync(join(root, ".public-ai", "rules", "extra.md"), "utf8"), "extra\n");
    assert.equal(listFiles(join(root, ".public-ai")).includes("skills/demo/SKILL.md"), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("empty source leaves the target", () => {
  const root = seedConsumer();
  try {
    sync(cfgFor(root));
    const empty = join(root, "empty");
    mkdirSync(empty);
    const cfg = cfgFor(root, { PUBLIC_AI_SYNC_SOURCE: empty });
    const result = spawnSync(process.execPath, [BIN], { encoding: "utf8", env: envFrom(cfg) });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /no files in the configured paths/);
    assert.equal(readFileSync(join(root, ".public-ai", "AGENTS.md"), "utf8"), "agents-v1\n");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("failed fetch leaves the target", () => {
  const root = seedConsumer();
  try {
    sync(cfgFor(root));
    const cfg = cfgFor(root, { PUBLIC_AI_SYNC_SOURCE: "https://127.0.0.1:1/no-such-public-ai" });
    const result = spawnSync(process.execPath, [BIN], { encoding: "utf8", env: envFrom(cfg) });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /failed to fetch/);
    assert.equal(readFileSync(join(root, ".public-ai", "AGENTS.md"), "utf8"), "agents-v1\n");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("skip env does not write a target", () => {
  const root = seedConsumer();
  try {
    assert.equal(sync(cfgFor(root, { PUBLIC_AI_SYNC_SKIP: "1" })), 0);
    assert.equal(listFiles(join(root, ".public-ai")).length, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("nextPatch increments the patch", () => {
  const got = nextPatch("9.9.9");
  assert.equal(got.split(".")[0], "9");
  assert.equal(got.split(".")[2], "10");
});

test("bump dry-run skips publish without a token", () => {
  const result = spawnSync(process.execPath, [BUMP, "--dry-run"], {
    encoding: "utf8",
    env: { ...process.env, NPM_TOKEN: "" },
    cwd: ROOT,
  });
  assert.equal(result.status, 0);
  assert.match(result.stdout, /next version/);
  assert.match(result.stdout, /skip npm publish/);
});

function seedConsumer() {
  const root = tempDir();
  writeFileSync(join(root, "package.json"), JSON.stringify({ name: "demo-app" }));
  writeTree(join(root, "ai-source"), {
    "AGENTS.md": "agents-v1\n",
    "rules/sample.md": "rule-v1\n",
    "skills/demo/SKILL.md": "skill-v1\n",
  });
  return root;
}

function cfgFor(root, extra = {}) {
  return loadConfig({
    ...process.env,
    PUBLIC_AI_SYNC_SKIP: "",
    PUBLIC_AI_SYNC_ROOT: root,
    PUBLIC_AI_SYNC_SOURCE: join(root, "ai-source"),
    PUBLIC_AI_SYNC_TARGET: ".public-ai",
    PUBLIC_AI_SYNC_PATHS: "rules,skills,AGENTS.md",
    PUBLIC_AI_SYNC_REF: "main",
    ...extra,
  });
}

function envFrom(cfg) {
  return {
    ...process.env,
    PUBLIC_AI_SYNC_SKIP: "",
    PUBLIC_AI_SYNC_ROOT: cfg.root,
    PUBLIC_AI_SYNC_SOURCE: cfg.source,
    PUBLIC_AI_SYNC_TARGET: cfg.targetRel,
    PUBLIC_AI_SYNC_PATHS: cfg.paths.join(","),
    PUBLIC_AI_SYNC_REF: cfg.ref,
  };
}

function writeTree(dir, files) {
  for (const [rel, body] of Object.entries(files)) {
    const path = join(dir, rel);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, body);
  }
}

function tempDir() {
  return mkdtempSync(join(tmpdir(), "pai-"));
}
