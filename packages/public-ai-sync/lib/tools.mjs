import { existsSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { SyncError } from "./errors.mjs";

const NPM_PREFIX = "public-ai:";
const SYNC_BIN = "public-ai-sync";

export const TOOLS = {
  "lint-docs": "scripts/lint/lint-docs.sh",
  "lint-explainer": "scripts/lint/lint-explainer.sh",
  lint: "scripts/lint/lint-clean-code.sh",
  "code-quality": "skills/setup-repo/assets/scripts/code-quality-check.sh",
  privacy: "scripts/check-privacy.sh",
  "install-hooks": "scripts/install-hooks.sh",
};

export const LIFECYCLE_SCRIPTS = {
  postinstall: SYNC_BIN,
  prepare: SYNC_BIN,
};

export function npmScripts() {
  const scripts = { [`${NPM_PREFIX}sync`]: SYNC_BIN };
  for (const [flag, rel] of Object.entries(TOOLS)) {
    scripts[`${NPM_PREFIX}${flag}`] = `bash ${rel}`;
  }
  return scripts;
}

export function runTool(job) {
  const rel = TOOLS[job.flag];
  const script = join(job.cfg.root, rel);
  if (!existsSync(script)) {
    throw new SyncError(`public-ai-sync: ${rel} is not installed; run with no arguments first`);
  }
  return exitStatus(spawnSync("bash", [script, ...job.args], {
    cwd: job.cfg.root,
    stdio: "inherit",
  }));
}

function exitStatus(result) {
  if (result.status === 0) return 0;
  if (result.status == null) return 1;
  return result.status;
}
