import { makeFinding } from "./catalog.mjs";
import { WARN } from "./model.mjs";
import { indentWidth } from "./rules_order_span.mjs";

const MIN_LOGIC = 8;
const VERDICT = ["guard-clause", WARN];
const IF_LINE = /^\s*if\b/;
const ELSE_WORD = /\belse\b/;

export function guardFindings(ctx, func) {
  if (func.logic < MIN_LOGIC) return [];
  if (ctx.src.lang === "python") return pythonGuard(ctx, func);
  if (ctx.src.spec.family === "brace") return braceGuard(ctx, func);
  return [];
}

function pythonGuard(ctx, func) {
  const lines = contentLines(ctx.src, func);
  if (!lines.length) return [];
  const first = ctx.src.masked[lines[0]];
  if (!IF_LINE.test(first) || !first.trimEnd().endsWith(":") || ELSE_WORD.test(first)) return [];
  const indent = indentWidth(first);
  for (const number of lines.slice(1)) {
    if (indentWidth(ctx.src.masked[number]) <= indent) return [];
  }
  return finding(ctx, func);
}

function braceGuard(ctx, func) {
  const lines = contentLines(ctx.src, func);
  if (!lines.length) return [];
  const first = ctx.src.masked[lines[0]];
  if (!IF_LINE.test(first) || ELSE_WORD.test(first)) return [];
  let state = { depth: 0, opened: false };
  for (let index = 0; index < lines.length; index++) {
    const step = closedIf(ctx.src.masked[lines[index]], state);
    state = step;
    if (!step.closed) continue;
    if (ELSE_WORD.test(step.rest) || index < lines.length - 1) return [];
    return finding(ctx, func);
  }
  return [];
}

function contentLines(src, func) {
  let end = func.end;
  const closer = src.masked[end] ? src.masked[end].trim() : "";
  if (closer === "}" || closer === "};") end -= 1;
  const lines = [];
  for (let number = func.headerEnd + 1; number <= end; number++) {
    if (src.masked[number].trim()) lines.push(number);
  }
  return lines;
}

function finding(ctx, func) {
  const message = `${func.name}() wraps its body in if; return early instead`;
  return [makeFinding([ctx.src.path, func.start], VERDICT, message)];
}

function closedIf(text, state) {
  let depth = state.depth;
  let opened = state.opened;
  for (let col = 0; col < text.length; col++) {
    const char = text[col];
    if (char === "{") {
      depth += 1;
      opened = true;
      continue;
    }
    if (char !== "}" || depth === 0) continue;
    depth -= 1;
    if (opened && depth === 0) return { depth, opened, rest: text.slice(col + 1), closed: true };
  }
  return { depth, opened, rest: "", closed: false };
}
