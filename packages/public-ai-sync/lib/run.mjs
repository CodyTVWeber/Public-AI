import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadConfig } from "./config.mjs";
import { materializeSource } from "./fetch-source.mjs";
import { ensureGitignore } from "./gitignore.mjs";
import { replaceTarget } from "./replace-target.mjs";
import { rmIfExists } from "./fs-util.mjs";

export function run(argv, env = process.env) {
  const cfg = loadConfig(env);
  if (argv[0] === "ignore") {
    if (!cfg.skip) ensureGitignore(cfg.root, cfg.targetRel);
    return 0;
  }
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
  ensureGitignore(cfg.root, cfg.targetRel);
}
