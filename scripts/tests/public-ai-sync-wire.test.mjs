import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, readlinkSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { DEFAULT_PATHS, loadConfig } from "../../packages/public-ai-sync/lib/config.mjs";
import { sync } from "../../packages/public-ai-sync/lib/run.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const BIN = join(ROOT, "packages", "public-ai-sync", "bin", "sync.mjs");
const SETTINGS = join(ROOT, ".claude", "settings.json");

test("default paths include the full AI environment", () => {
  const root = tempDir();
  try {
    writeFileSync(join(root, "package.json"), JSON.stringify({ name: "demo-app" }));
    const cfg = loadConfig(baseEnv(root, { PUBLIC_AI_SYNC_PATHS: "" }));
    assert.deepEqual(cfg.paths, DEFAULT_PATHS);
    assert.ok(DEFAULT_PATHS.includes("scripts"));
    assert.ok(DEFAULT_PATHS.includes("PRIVACY.md"));
    assert.ok(DEFAULT_PATHS.includes(".claude"));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("default paths cover Claude hook commands", () => {
  const settings = JSON.parse(readFileSync(SETTINGS, "utf8"));
  for (const rel of hookRels(settings)) {
    assert.ok(coveredByDefaults(rel), rel);
  }
});

test("sync links boot paths and gitignores them", () => {
  const root = seedPack();
  try {
    assert.equal(sync(cfgOf(root)), 0);
    assert.equal(readlinkSync(join(root, "AGENTS.md")), ".public-ai/AGENTS.md");
    assert.equal(readlinkSync(join(root, "scripts", "lint")), "../.public-ai/scripts/lint");
    assert.equal(readFileSync(join(root, "scripts", "app.sh"), "utf8"), "mine\n");
    const ignore = readFileSync(join(root, ".gitignore"), "utf8");
    assert.match(ignore, /^\.public-ai\/$/m);
    assert.match(ignore, /^AGENTS\.md$/m);
    assert.match(ignore, /^scripts\/lint\/$/m);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("existing agent file stays in place", () => {
  const root = seedPack();
  try {
    writeFileSync(join(root, "AGENTS.md"), "mine\n");
    assert.equal(sync(cfgOf(root)), 0);
    assert.equal(readFileSync(join(root, "AGENTS.md"), "utf8"), "mine\n");
    assert.equal(readFileSync(join(root, ".public-ai", "AGENTS.md"), "utf8"), "agents-v1\n");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("install injects npm scripts and keeps an existing postinstall", () => {
  const root = seedPack();
  try {
    writeFileSync(join(root, "package.json"), JSON.stringify({ name: "demo-app", scripts: { postinstall: "echo keep" } }));
    assert.equal(sync(cfgOf(root)), 0);
    const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
    assert.equal(pkg.scripts.postinstall, "echo keep");
    assert.equal(pkg.scripts.prepare, "public-ai-sync");
    assert.equal(pkg.scripts["public-ai:code-quality"], "bash skills/setup-repo/assets/scripts/code-quality-check.sh");
    assert.equal(pkg.scripts["public-ai:lint-docs"], "bash scripts/lint/lint-docs.sh");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("install runs the git-hooks script when it is present", () => {
  const root = seedPack();
  try {
    assert.equal(sync(cfgOf(root)), 0);
    assert.equal(readFileSync(join(root, "hooked"), "utf8"), "yes\n");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("code-quality subcommand runs the wired script", () => {
  const root = seedPack();
  try {
    assert.equal(sync(cfgOf(root)), 0);
    const result = spawnSync(process.execPath, [BIN, "code-quality"], {
      encoding: "utf8",
      env: envOf(cfgOf(root)),
    });
    assert.equal(result.status, 0);
    assert.equal(readFileSync(join(root, "quality.out"), "utf8"), "quality-ok\n");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

function seedPack() {
  const root = tempDir();
  writeFileSync(join(root, "package.json"), JSON.stringify({ name: "demo-app" }));
  mkdirSync(join(root, "scripts"), { recursive: true });
  writeFileSync(join(root, "scripts", "app.sh"), "mine\n");
  writeTree(join(root, "ai-source"), {
    "AGENTS.md": "agents-v1\n",
    "rules/sample.md": "rule-v1\n",
    "scripts/lint/hello.sh": "#!/usr/bin/env bash\necho lint\n",
    "scripts/install-hooks.sh": "#!/usr/bin/env bash\nprintf 'yes\\n' > hooked\n",
    "skills/setup-repo/assets/scripts/code-quality-check.sh": "#!/usr/bin/env bash\nprintf 'quality-ok\\n' > quality.out\n",
    ".claude/settings.json": "{}\n",
  });
  return root;
}

function cfgOf(root) {
  return loadConfig(baseEnv(root, {
    PUBLIC_AI_SYNC_PATHS: "AGENTS.md,rules,scripts,skills,.claude",
  }));
}

function envOf(cfg) {
  return baseEnv(cfg.root, {
    PUBLIC_AI_SYNC_SOURCE: cfg.source,
    PUBLIC_AI_SYNC_TARGET: cfg.targetRel,
    PUBLIC_AI_SYNC_PATHS: cfg.paths.join(","),
    PUBLIC_AI_SYNC_REF: cfg.ref,
  });
}

function baseEnv(root, extra = {}) {
  return {
    ...process.env,
    PUBLIC_AI_SYNC_SKIP: "",
    PUBLIC_AI_SYNC_ROOT: root,
    PUBLIC_AI_SYNC_SOURCE: join(root, "ai-source"),
    PUBLIC_AI_SYNC_TARGET: ".public-ai",
    PUBLIC_AI_SYNC_REF: "main",
    ...extra,
  };
}

function hookRels(settings) {
  return collectCommands(settings).map(hookRel);
}

function collectCommands(node) {
  if (Array.isArray(node)) return node.flatMap(collectCommands);
  if (!node || typeof node !== "object") return [];
  const here = typeof node.command === "string" ? [node.command] : [];
  return here.concat(Object.values(node).flatMap(collectCommands));
}

function hookRel(command) {
  return command.replace(/^"\$CLAUDE_PROJECT_DIR"\//, "").split(/\s+/)[0];
}

function coveredByDefaults(rel) {
  return DEFAULT_PATHS.some((path) => rel === path || rel.startsWith(`${path}/`));
}

function writeTree(dir, files) {
  for (const [rel, body] of Object.entries(files)) {
    const path = join(dir, rel);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, body);
  }
}

function tempDir() {
  return mkdtempSync(join(tmpdir(), "pai-wire-"));
}
