import fs from "node:fs";
import path from "node:path";
import { loadRecord } from "./record.mjs";

export const CORE_SCRIPTS = ["code-quality-check.sh", "check-clean-code.sh", "check-mr-size.sh",
  "check-mr-size-app.sh", "check-mr-size-support.sh", "check-mr-size-docs.sh", "pre-push-gate.sh",
  "claude-pre-tool-guard.sh", "post-git-check.sh", "git-scan.sh", "lint-docs.sh"];

export function result(id, status, detail) {
  return { id, status, detail };
}

export function fileHas(file, needle) {
  try {
    return fs.readFileSync(file, "utf8").includes(needle);
  } catch {
    return false;
  }
}

export function loadManifest(root) {
  return loadRecord(root);
}

export function isLocal(manifest) {
  return Boolean(manifest) && manifest.mode === "local";
}

export function settingsFile(root, manifest) {
  return path.join(root, ".claude", isLocal(manifest) ? "settings.local.json" : "settings.json");
}
