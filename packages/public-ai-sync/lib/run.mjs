import { existsSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { loadConfig } from "./config.mjs";
import { materializeSource } from "./fetch-source.mjs";
import { ensureGitignore } from "./gitignore.mjs";
import { replaceTarget } from "./replace-target.mjs";
import { rmIfExists } from "./fs-util.mjs";
import { TOOLS, runTool } from "./tools.mjs";
import { wireConsumer } from "./wire.mjs";

export function run(argv, env = process.env) {
  const cfg = loadConfig(env);
  if (argv[0] === "ignore") return ignoreOnly(cfg);
  if (TOOLS[argv[0]]) return runTool({ cfg, flag: argv[0], args: argv.slice(1) });
  return sync(cfg);
}

export function sync(cfg) {
  if (cfg.skip) {
    process.stderr.write("public-ai-sync: skip\n");
    return 0;
  }
  const work = mkdtempSync(join(tmpdir(), "public-ai-sync-"));
  return runSync(cfg, work);
}

function ignoreOnly(cfg) {
  if (!cfg.skip) ensureGitignore(cfg.root, [cfg.targetRel]);
  return 0;
}

function runSync(cfg, work) {
  try {
    fillThenSwap(cfg, work);
    return 0;
  } finally {
    rmIfExists(work);
  }
}

function fillThenSwap(cfg, work) {
  const staging = join(work, "staging");
  materializeSource({ cfg, staging, gitDir: join(work, "git") });
  replaceTarget(staging, cfg.target);
  const links = wireConsumer(cfg);
  ensureGitignore(cfg.root, [cfg.targetRel, ...links]);
  installGitHooks(cfg.root);
}

function installGitHooks(root) {
  const script = join(root, "scripts", "install-hooks.sh");
  if (!existsSync(script)) return;
  const result = spawnSync("bash", [script], { cwd: root, encoding: "utf8" });
  if (result.status === 0) return;
  process.stderr.write(`public-ai-sync: git hooks not installed (${exitLabel(result)})\n`);
}

function exitLabel(result) {
  if (result.status == null) return result.error?.message || "failed";
  return `exit ${result.status}`;
}
