import { test } from "node:test";
import assert from "node:assert/strict";
import {
  accessSync,
  chmodSync,
  constants,
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readlinkSync,
  rmSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { DEFAULT_PATHS, loadConfig } from "../../packages/public-ai-sync/lib/config.mjs";
import { sync } from "../../packages/public-ai-sync/lib/run.mjs";
import { TOOLS } from "../../packages/public-ai-sync/lib/tools.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const BIN = join(ROOT, "packages", "public-ai-sync", "bin", "sync.mjs");
const SETTINGS = join(ROOT, ".claude", "settings.json");
const SHELL_STUB = "#!/usr/bin/env bash\nexit 0\n";
const EXEC_MODE = 0o755;
const LINT_PREFIX = "scripts/lint/";

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
  for (const rel of hookRels(readSettings())) {
    assert.ok(coveredByDefaults(rel), rel);
  }
});

test("sync links boot paths and gitignores directory symlinks", () => {
  const root = seedPack();
  try {
    gitInit(root);
    assert.equal(sync(cfgOf(root)), 0);
    assert.equal(readlinkSync(join(root, "AGENTS.md")), ".public-ai/AGENTS.md");
    assert.equal(readlinkSync(join(root, "scripts", "lint")), "../.public-ai/scripts/lint");
    assert.equal(readFileSync(join(root, "scripts", "app.sh"), "utf8"), "mine\n");
    const ignore = readFileSync(join(root, ".gitignore"), "utf8");
    assert.match(ignore, /^\.public-ai\/$/m);
    assert.match(ignore, /^AGENTS\.md$/m);
    assert.match(ignore, /^scripts\/lint$/m);
    assert.match(ignore, /^\.claude$/m);
    assertIgnored(root, ".claude");
    assertIgnored(root, "scripts/lint");
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

test("existing rules directory is left unmerged", () => {
  const root = seedPack();
  try {
    mkdirSync(join(root, "rules"));
    writeFileSync(join(root, "rules", "local.md"), "local\n");
    assert.equal(sync(cfgOf(root)), 0);
    assert.equal(lstatSync(join(root, "rules")).isSymbolicLink(), false);
    assert.equal(readFileSync(join(root, "rules", "local.md"), "utf8"), "local\n");
    assert.equal(existsSync(join(root, "rules", "sample.md")), false);
    assert.equal(readFileSync(join(root, ".public-ai", "rules", "sample.md"), "utf8"), "rule-v1\n");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("second sync removes a boot link omitted from paths", () => {
  const root = seedPack();
  try {
    assert.equal(sync(cfgOf(root)), 0);
    assert.equal(lstatSync(join(root, "skills")).isSymbolicLink(), true);
    const narrower = loadConfig(baseEnv(root, {
      PUBLIC_AI_SYNC_PATHS: "AGENTS.md,rules,scripts,.claude",
    }));
    assert.equal(sync(narrower), 0);
    assert.throws(() => lstatSync(join(root, "skills")), { code: "ENOENT" });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("merge under scripts drops a stale owned child", () => {
  const root = seedPack();
  try {
    assert.equal(sync(cfgOf(root)), 0);
    const lint = join(root, "scripts", "lint");
    const target = join(root, ".public-ai", "scripts", "lint", "lint-docs.sh");
    unlinkSync(lint);
    mkdirSync(lint);
    symlinkSync(relative(lint, target), join(lint, "gone.sh"));
    assert.equal(sync(cfgOf(root)), 0);
    assert.throws(() => lstatSync(join(lint, "gone.sh")), { code: "ENOENT" });
    assert.equal(lstatSync(join(lint, "lint-docs.sh")).isSymbolicLink(), true);
    assert.equal(lstatSync(lint).isDirectory(), true);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("install injects public-ai scripts and keeps an existing postinstall", () => {
  const root = seedPack();
  try {
    writeFileSync(join(root, "package.json"), JSON.stringify({
      name: "demo-app",
      scripts: { postinstall: "echo keep" },
    }));
    assert.equal(sync(cfgOf(root)), 0);
    const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
    assert.equal(pkg.scripts.postinstall, "echo keep");
    assert.equal("prepare" in pkg.scripts, false);
    assert.equal(pkg.scripts["public-ai:sync"], "public-ai-sync");
    for (const [name, rel] of Object.entries(TOOLS)) {
      assert.equal(pkg.scripts[`public-ai:${name}`], `bash ${rel}`, name);
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("lint directory link reaches every lint script", () => {
  const root = seedPack();
  try {
    assert.equal(sync(cfgOf(root)), 0);
    for (const name of lintScriptNames()) {
      assert.equal(existsSync(join(root, "scripts", "lint", name)), true, name);
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("synced hook commands are executable at the consumer root", () => {
  const root = seedPack();
  try {
    assert.equal(sync(cfgOf(root)), 0);
    for (const rel of new Set(hookRels(readSettings()))) assertExecutable(join(root, rel));
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
  writeTree(join(root, "ai-source"), sourceFiles());
  return root;
}

function sourceFiles() {
  const files = {
    "AGENTS.md": "agents-v1\n",
    "rules/sample.md": "rule-v1\n",
    "scripts/install-hooks.sh": "#!/usr/bin/env bash\nprintf 'yes\\n' > hooked\n",
    "skills/setup-repo/assets/scripts/code-quality-check.sh": "#!/usr/bin/env bash\nprintf 'quality-ok\\n' > quality.out\n",
    ".claude/settings.json": "{}\n",
  };
  for (const rel of Object.values(TOOLS)) if (!files[rel]) files[rel] = SHELL_STUB;
  for (const rel of hookRels(readSettings())) if (!files[rel]) files[rel] = SHELL_STUB;
  return files;
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

function lintScriptNames() {
  return Object.values(TOOLS)
    .filter((rel) => rel.startsWith(LINT_PREFIX))
    .map((rel) => rel.slice(LINT_PREFIX.length));
}

function readSettings() {
  return JSON.parse(readFileSync(SETTINGS, "utf8"));
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

function assertIgnored(root, rel) {
  const result = spawnSync("git", ["check-ignore", "-v", "--", rel], {
    cwd: root,
    encoding: "utf8",
  });
  assert.equal(result.status, 0, `${rel}\n${result.stderr}`);
  const pattern = result.stdout.split("\t")[0].split(":").slice(2).join(":");
  assert.equal(pattern.endsWith("/"), false, result.stdout);
}

function assertExecutable(path) {
  assert.equal(existsSync(path), true, path);
  accessSync(path, constants.X_OK);
}

function gitInit(root) {
  const result = spawnSync("git", ["init", "-q"], { cwd: root, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
}

function writeTree(dir, files) {
  for (const [rel, body] of Object.entries(files)) {
    const path = join(dir, rel);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, body);
    if (rel.endsWith(".sh")) chmodSync(path, EXEC_MODE);
  }
}

function tempDir() {
  return mkdtempSync(join(tmpdir(), "pai-wire-"));
}
