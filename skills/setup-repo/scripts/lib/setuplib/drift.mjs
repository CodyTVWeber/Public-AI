import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { STALE_COPY } from "./stale.mjs";

export const CHANGED_UPSTREAM = "changed-upstream";
export const MODIFIED_LOCALLY = "modified-locally";
export const MISSING = "missing";
const REMOVED_UPSTREAM = "removed-upstream";

export function fileHash(file) {
  try {
    return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
  } catch {
    return null;
  }
}

function entryStatus(places, file, entry) {
  const [root, sourceBase] = places;
  const installed = fileHash(path.join(root, file));
  if (installed === null) return MISSING;
  const upstream = fileHash(path.join(sourceBase, entry.source));
  if (installed === upstream) return null;
  if (installed !== entry.hash) return MODIFIED_LOCALLY;
  return upstream !== null ? CHANGED_UPSTREAM : REMOVED_UPSTREAM;
}

export function computeDrift(root, record, sourceBase) {
  const files = Object.entries((record && record.files) || {}).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  const found = [];
  for (const [file, entry] of files) {
    const status = entryStatus([root, sourceBase], file, entry);
    if (status) found.push({ path: file, status });
  }
  return found;
}

export function differsReason(driftMap, file, stale = null) {
  const status = driftMap.get(file) || stale;
  if (status === STALE_COPY) return "unchanged copy of an earlier upstream version: rerun with --upgrade to replace it";
  if (status === CHANGED_UPSTREAM) return "changed upstream since install: rerun with --upgrade (or --force) to take the new version";
  if (status === MODIFIED_LOCALLY) return "modified locally since install: kept; diff it, or rerun with --force to overwrite";
  return "exists and differs: diff it and keep the stricter value, or rerun with --force";
}
