import { makeFinding } from "./catalog.mjs";
import { ERROR, WARN } from "./model.mjs";
import { isBoolFlag } from "./params.mjs";
import { mutationFindings } from "./rules_mutation.mjs";
import { tryFindings } from "./rules_try.mjs";

function grade(value, errorAt, warnAt) {
  if (value >= errorAt) return ERROR;
  return value >= warnAt ? WARN : null;
}

function lengthFindings(ctx, func) {
  if (ctx.src.isTest) return [];
  const severity = grade(func.logic, ctx.limits.funcError + 1, ctx.limits.funcWarn + 1);
  if (severity === null) return [];
  const message = `${func.name}() is ${func.logic} lines of logic`;
  return [makeFinding([ctx.src.path, func.start], ["function-length", severity], message)];
}

function paramFindings(ctx, func) {
  const count = func.params.length;
  const severity = grade(count, ctx.limits.paramsError, ctx.limits.paramsError - 1);
  if (severity === null) return [];
  const message = `${func.name}() takes ${count} params`;
  return [makeFinding([ctx.src.path, func.start], ["param-count", severity], message)];
}

function nestingFindings(ctx, func) {
  const severity = grade(func.maxDepth, ctx.limits.nestError, ctx.limits.nestWarn);
  if (severity === null) return [];
  const message = `${func.name}() nests control flow ${func.maxDepth} deep`;
  return [makeFinding([ctx.src.path, func.depthLine], ["nesting-depth", severity], message)];
}

function flagFindings(ctx, func) {
  const flags = func.params.filter(isBoolFlag).map((param) => param.name);
  if (!flags.length) return [];
  const message = `${func.name}() takes boolean flag ${flags.join(", ")}`;
  return [makeFinding([ctx.src.path, func.start], ["bool-flag-param", WARN], message)];
}

const CHECKS = [lengthFindings, paramFindings, nestingFindings, flagFindings, mutationFindings, tryFindings];

export function checkFunctions(ctx) {
  const findings = [];
  for (const func of ctx.src.structure.functions) {
    if (!ctx.change.touches(func.start, func.end)) continue;
    for (const check of CHECKS) findings.push(...check(ctx, func));
  }
  return findings;
}
