import { existsSync, readdirSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";

export function rmIfExists(path) {
  if (existsSync(path)) rmSync(path, { recursive: true, force: true });
}

export function listFiles(dir) {
  if (!existsSync(dir)) return [];
  const out = [];
  walkFiles({ root: dir, rel: "", out });
  return out;
}

function walkFiles(state) {
  const here = state.rel ? join(state.root, state.rel) : state.root;
  for (const name of readdirSync(here)) {
    const child = state.rel ? join(state.rel, name) : name;
    if (statSync(join(state.root, child)).isDirectory()) walkFiles({ ...state, rel: child });
    else state.out.push(child);
  }
}
