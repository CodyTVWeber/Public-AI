import { cpSync, existsSync, mkdirSync, renameSync } from "node:fs";
import { dirname } from "node:path";
import { rmIfExists } from "./fs-util.mjs";

export function replaceTarget(staging, target) {
  const next = `${target}.next`;
  const prev = `${target}.prev`;
  rmIfExists(next);
  rmIfExists(prev);
  mkdirSync(dirname(target), { recursive: true });
  cpSync(staging, next, { recursive: true });
  if (existsSync(target)) renameSync(target, prev);
  swapNext({ next, prev, target });
  rmIfExists(prev);
}

function swapNext(paths) {
  try {
    renameSync(paths.next, paths.target);
  } catch (err) {
    restorePrev(paths);
    throw err;
  }
}

function restorePrev(paths) {
  if (existsSync(paths.prev) && !existsSync(paths.target)) renameSync(paths.prev, paths.target);
}
