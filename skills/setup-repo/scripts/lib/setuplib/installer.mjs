import path from "node:path";
import { run } from "./util.mjs";

const INSTALL_TIMEOUT_MS = 120000;

export function overwriteFlags(ctx) {
  return [...ctx.upgradePaths].sort().flatMap((item) => ["--overwrite", item]);
}

export function runInstall(ctx, flags) {
  const command = path.join(ctx.skillDir, "scripts", "install.sh");
  const result = run(command, [ctx.root, ...flags], { timeout: INSTALL_TIMEOUT_MS });
  if (!result || result.status !== 0) {
    throw new Error("install.sh failed: " + (result ? result.stderr.trim().slice(-300) : "not runnable"));
  }
  return JSON.parse(result.stdout);
}

export function noteInstalled(ctx, report) {
  for (const item of report.files) {
    if (["create", "overwrite", "same"].includes(item.status)) ctx.installed.set(item.path, item.src);
  }
}
