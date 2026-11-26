import path from "node:path";
import { fileURLToPath } from "node:url";
import { gitOut, isDir, isFile, realpath } from "./util.mjs";

export const SKILL_DIR = realpath(path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "..", ".."));
const UNKNOWN_SHA = "unknown";

export function findPublicRoot() {
  const root = realpath(path.join(SKILL_DIR, "..", ".."));
  const marker = path.join(root, "scripts", "check-privacy.sh");
  return isDir(path.join(root, "skills", "ai-risk")) && isFile(marker) ? root : null;
}

export function sourceRoot() {
  return findPublicRoot() || SKILL_DIR;
}

export function sourceSha(root) {
  const out = gitOut(root, "rev-parse", "HEAD").trim();
  return out || UNKNOWN_SHA;
}
