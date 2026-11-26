import { makeFinding } from "./catalog.mjs";
import { WARN } from "./model.mjs";
import { callFindings } from "./rules_order_calls.mjs";
import { sameBlock } from "./rules_order_span.mjs";

const ORDER = ["function-order", WARN];
const DUNDER = /^__\w+__$/;
const PRIVATE_WORD = /\b(?:private|protected)\b/;
const EXPORT_WORD = /\bexport\b/;
const PUB_WORD = /\bpub\b/;

export function orderFindings(ctx) {
  return groupsOf(ctx.src).flatMap((functions) => [
    ...publicFindings(ctx, functions), ...callFindings(ctx, functions),
  ]);
}

function publicFindings(ctx, functions) {
  const findings = [];
  for (const helper of functions) {
    if (!isHelper(ctx.src, helper) || !ctx.change.touches(helper.start, helper.end)) continue;
    const target = nearestPublic(ctx.src, { helper, functions });
    if (target === null) continue;
    const message = `${helper.name}() sits above public ${target.name}(); public API stays on top`;
    findings.push(makeFinding([ctx.src.path, helper.start], ORDER, message));
  }
  return findings;
}

function groupsOf(src) {
  const groups = new Map();
  for (const func of src.structure.functions) {
    const parent = parentOf(func, src.structure.functions);
    const key = parent === null ? "root" : parent;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(func);
  }
  return [...groups.values()];
}

function nearestPublic(src, query) {
  let target = null;
  for (const other of query.functions) {
    const pair = { left: query.helper, right: other };
    if (other.start <= query.helper.start || isHelper(src, other) || !sameBlock(src, pair)) continue;
    if (target === null || other.start < target.start) target = other;
  }
  return target;
}

function parentOf(func, functions) {
  const containers = functions.filter((other) => contained(other, func));
  if (!containers.length) return null;
  return containers.reduce((best, other) => (other.end - other.start < best.end - best.start ? other : best));
}

function isHelper(src, func) {
  const { lang } = src;
  if (lang === "python" || lang === "ruby") return func.name.startsWith("_") && !DUNDER.test(func.name);
  if (lang === "go") return func.name[0] === func.name[0].toLowerCase();
  const header = headerText(src, func);
  if (lang === "rust") return !PUB_WORD.test(header);
  if (lang === "js") return !EXPORT_WORD.test(header);
  if (lang === "shell") return false;
  return PRIVATE_WORD.test(header);
}

function contained(outer, inner) {
  return outer !== inner && outer.start < inner.start && outer.end >= inner.end;
}

function headerText(src, func) {
  return src.masked.slice(func.start, func.headerEnd + 1).join(" ");
}
