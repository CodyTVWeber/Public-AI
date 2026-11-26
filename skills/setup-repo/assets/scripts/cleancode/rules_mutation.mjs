import { makeFinding } from "./catalog.mjs";
import { ERROR, WARN, escapeRegExp, startsWithAny } from "./model.mjs";

const LANGUAGES = new Set(["js", "python", "kotlin", "java", "cs", "scala"]);
const MUTATOR_PREFIX = new RegExp(
  "^_*(?:set|fill|populate|write|apply|mutate|update|init|register|configure|merge"
  + "|assign|append|push|add|reset|clear|constructor)", "i");
const OUT_MARKERS = ["ref ", "out ", "inout ", "&mut "];
const IDIOM_NAMES = new Set(["res", "resp", "response", "req", "request", "ctx", "event", "evt", "self", "this"]);
const REF_NAME = /^(?:ref|\w+Ref)$/;
const RULE = "param-mutation";

function mutationPatterns(name) {
  const start = "(?<![\\w.$])" + escapeRegExp(name);
  const target = start + "(?:\\.\\w+|\\[[^\\]]*\\])+\\s*(?:[-+*/|&^%]|<<|>>|\\*\\*|//|\\?\\?)?=(?![=>])";
  const compound = start + "\\s*(?:\\+=|-=|\\*=|/=|\\|=|&=)";
  return [new RegExp(target), new RegExp(compound)];
}

function firstHit(body, patterns) {
  return body.find(([, text]) => patterns.some((pattern) => pattern.test(text))) || null;
}

function isIdiom(name, text) {
  if (IDIOM_NAMES.has(name)) return true;
  return REF_NAME.test(name) && new RegExp(escapeRegExp(name) + "\\.current\\b").test(text);
}

export function mutationFindings(ctx, func) {
  if (!LANGUAGES.has(ctx.src.lang) || MUTATOR_PREFIX.test(func.name)) return [];
  const masked = ctx.src.masked;
  const body = [];
  for (let number = func.headerEnd + 1; number <= func.end; number++) body.push([number, masked[number]]);
  const findings = [];
  for (const param of func.params) {
    if (!param.name || startsWithAny(param.raw, OUT_MARKERS)) continue;
    const hit = firstHit(body, mutationPatterns(param.name));
    if (hit === null) continue;
    const verdict = [RULE, isIdiom(param.name, hit[1]) ? WARN : ERROR];
    findings.push(makeFinding([ctx.src.path, hit[0]], verdict, `${func.name}() mutates parameter ${param.name}`));
  }
  return findings;
}
