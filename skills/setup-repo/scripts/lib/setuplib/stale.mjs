import path from "node:path";
import { gitOut, isFile, realpath } from "./util.mjs";

export const STALE_COPY = "stale-copy";

function pastBlobs(src) {
  const top = gitOut(path.dirname(src), "rev-parse", "--show-toplevel").trim();
  if (!top) return new Set();
  const rel = path.relative(realpath(top), realpath(src));
  const raw = gitOut(top, "log", "--follow", "--format=", "--raw", "--no-abbrev", "--", rel);
  const fields = raw.split("\n").filter((line) => line.startsWith(":")).map((line) => line.split(/\s+/));
  return new Set(fields.filter((parts) => parts.length > 3).map((parts) => parts[3]));
}

export function isStaleCopy(src, dest) {
  if (!isFile(src) || !isFile(dest)) return false;
  const blob = gitOut(path.dirname(src), "hash-object", "--", dest).trim();
  return Boolean(blob) && pastBlobs(src).has(blob);
}

export function takeStale(ctx, item) {
  if (ctx.driftMap.get(item.path) || !isStaleCopy(item.src, ctx.dest(item.path))) return null;
  if (ctx.options.upgrade) {
    ctx.upgradePaths.add(item.path);
    ctx.installed.set(item.path, item.src);
  }
  return STALE_COPY;
}
