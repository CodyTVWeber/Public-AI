import { makeFinding } from "./catalog.mjs";
import { ERROR, WARN } from "./model.mjs";

const NUMBER = /(?<![\w.$#@])-?(?:0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)[uUlLfFdD]?(?![\w])/g;
const INDEX = /\[[\s\d:+\-]*\]|\.group\(\s*\d+\s*\)/g;
const EXIT_CALL = /\bexit\w*\s*\(?\s*-?\d/;
const CONSTANT_LINE = new RegExp(
  "^\\s*(?:(?:export|public|private|protected|internal|static|final|const|readonly|val|var|let|pub|default)\\s+)*"
  + "[A-Z][A-Z0-9_]+\\b");
const CONSTANT_KEYWORD = /\b(?:const|static\s+final|final\s+static|readonly|enum)\b/;
const ALLOWED_VALUES = new Set([-1, 0, 1, 2]);
const SKIPPED_LANGUAGES = new Set(["shell"]);
const MAGIC = ["magic-number", WARN];
const EMPTY_CATCH = ["empty-catch", ERROR];
const INT_LITERAL = /^[+-]?(?:0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+|[1-9]\d*|0+)$/;
const FLOAT_LITERAL = /^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/;

function parseNumber(text) {
  if (INT_LITERAL.test(text)) {
    const negative = text.startsWith("-");
    const digits = text.replace(/^[+-]/, "");
    return negative ? -Number(digits) : Number(digits);
  }
  return FLOAT_LITERAL.test(text) ? parseFloat(text) : null;
}

function literalValue(token) {
  let text = token.replaceAll("_", "");
  if (!text.toLowerCase().replace(/^-+/, "").startsWith("0x")) text = text.replace(/[uUlLfFdD]+$/, "");
  return parseNumber(text);
}

function headerLines(functions) {
  const lines = new Set();
  for (const func of functions) for (let line = func.start; line <= func.headerEnd; line++) lines.add(line);
  return lines;
}

function exemptLine(text) {
  const stripped = text.trim();
  if (!stripped || stripped.startsWith("@")) return true;
  if (CONSTANT_LINE.test(text) || CONSTANT_KEYWORD.test(text)) return true;
  return EXIT_CALL.test(text);
}

function firstMagic(text) {
  for (const found of text.replace(INDEX, "").matchAll(NUMBER)) {
    const value = literalValue(found[0]);
    if (value !== null && !ALLOWED_VALUES.has(value)) return found[0];
  }
  return null;
}

export function magicFindings(ctx) {
  const { src } = ctx;
  if (src.isTest || SKIPPED_LANGUAGES.has(src.lang)) return [];
  const skipped = headerLines(src.structure.functions);
  const findings = [];
  for (let number = 1; number < src.masked.length; number++) {
    const text = src.masked[number];
    if (skipped.has(number) || !ctx.change.has(number) || exemptLine(text)) continue;
    const token = firstMagic(text);
    if (token) findings.push(makeFinding([src.path, number], MAGIC, "magic number " + token));
  }
  return findings;
}

export function emptyCatchFindings(ctx) {
  const findings = [];
  for (const block of ctx.src.structure.blocks) {
    if (block.kind === "catch" && block.empty && ctx.change.touches(block.start, block.end)) {
      findings.push(makeFinding([ctx.src.path, block.start], EMPTY_CATCH, "empty catch/except handler"));
    }
  }
  return findings;
}
