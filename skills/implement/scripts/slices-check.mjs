#!/usr/bin/env node
import { readFileSync } from "node:fs";

const NAME = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const GLOB_CHARS = "*?[{";

const isObject = (v) => v !== null && typeof v === "object" && !Array.isArray(v);

function repr(v) {
  if (v === null || v === undefined) return "None";
  if (typeof v === "boolean") return v ? "True" : "False";
  if (typeof v === "string") {
    const q = v.includes("'") && !v.includes('"') ? '"' : "'";
    return `${q}${v.replaceAll("\\", "\\\\").replaceAll(q, `\\${q}`).replaceAll("\n", "\\n")}${q}`;
  }
  return JSON.stringify(v);
}

const str = (v) => (typeof v === "string" ? v : repr(v));

function load(path) {
  let doc;
  try {
    doc = JSON.parse(readFileSync(path, "utf8"));
  } catch (err) {
    process.stderr.write(`unreadable input: ${err.message}\n`);
    process.exit(3);
  }
  const slices = isObject(doc) ? doc.slices : null;
  if (!Array.isArray(slices)) {
    process.stderr.write('input needs {"slices": [...]}\n');
    process.exit(3);
  }
  return slices;
}

function literalPrefix(path) {
  for (let i = 0; i < path.length; i++) if (GLOB_CHARS.includes(path[i])) return [path.slice(0, i), true];
  return path.endsWith("/") ? [path, true] : [path, false];
}

const normalize = (path) => (path.startsWith("./") ? path.slice(2) : path);

function overlaps(left, right) {
  const [lp, lg] = literalPrefix(left);
  const [rp, rg] = literalPrefix(right);
  if (!lg && !rg) return lp === rp;
  if (lg && rg) return lp.startsWith(rp) || rp.startsWith(lp);
  const [exact, pat] = rg ? [lp, rp] : [rp, lp];
  return exact.startsWith(pat) || pat.startsWith(`${exact}/`);
}

function pathErrors(name, paths) {
  if (!Array.isArray(paths) || !paths.length) return [`slice ${str(name)}: paths is empty`];
  const errors = [];
  for (const path of paths) {
    const bad = typeof path !== "string" || !path || path.startsWith("/") || path.split("/").includes("..");
    if (bad) errors.push(`slice ${str(name)}: invalid path ${repr(path)}`);
  }
  return errors;
}

function sliceErrors(slices, maxSlices) {
  const errors = [];
  const seen = new Set();
  if (slices.length > maxSlices) errors.push(`${slices.length} slices exceeds max ${maxSlices}`);
  for (const item of slices) {
    const name = isObject(item) ? item.name ?? null : null;
    const paths = isObject(item) ? item.paths : null;
    if (typeof name !== "string" || !NAME.test(name)) errors.push(`invalid slice name: ${repr(name)}`);
    else if (seen.has(name)) errors.push(`duplicate slice name: ${name}`);
    seen.add(name);
    errors.push(...pathErrors(name, paths));
  }
  return errors;
}

function pairOverlaps(left, right) {
  const found = [];
  for (const lpath of left.paths) {
    for (const rpath of right.paths) {
      if (typeof lpath === "string" && typeof rpath === "string" && overlaps(normalize(lpath), normalize(rpath))) {
        found.push({ a: left.name ?? null, b: right.name ?? null, pattern: `${lpath} | ${rpath}` });
      }
    }
  }
  return found;
}

function findOverlaps(slices) {
  const valid = slices.filter((s) => isObject(s) && Array.isArray(s.paths));
  const found = [];
  valid.forEach((left, i) => {
    for (const right of valid.slice(i + 1)) found.push(...pairOverlaps(left, right));
  });
  return found;
}

const slices = load(process.argv[2]);
const errors = sliceErrors(slices, Number(process.argv[3]));
const found = findOverlaps(slices);
const ok = !errors.length && !found.length;
console.log(JSON.stringify({ ok, errors, overlaps: found }));
process.exit(ok ? 0 : 1);
