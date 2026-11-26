import { isTestPath, specFor } from "./languages.mjs";
import { lex, splitLines } from "./lexing.mjs";
import { buildStructure } from "./structure.mjs";

const DOC_QUOTES = ['"""', "'''"];
const BLOCK_OPENER = /^(?:async\s+)?(?:if|elif|else|for|while|try|except|finally|with|match|case)\b/;

function previousCodeLine(masked, number) {
  for (let index = number - 1; index > 0; index--) {
    if (masked[index].trim()) return masked[index].trim();
  }
  return "";
}

function docstringRanges(lexed) {
  const masked = lexed.masked;
  const found = [];
  for (const [start, col, end] of lexed.triples) {
    if (masked[start].slice(0, col).trim()) continue;
    if (!DOC_QUOTES.some((quote) => masked[end].trimEnd().endsWith(quote))) continue;
    const previous = previousCodeLine(masked, start);
    if (previous === "" || previous.endsWith(":")) found.push([start, end, !BLOCK_OPENER.test(previous)]);
  }
  return found;
}

function withoutRanges(masked, ranges) {
  const hidden = new Set();
  for (const [start, end] of ranges) for (let number = start; number <= end; number++) hidden.add(number);
  return masked.map((line, number) => (hidden.has(number) ? "" : line));
}

export function buildSource(path, text) {
  const spec = specFor(path);
  if (spec === null) return null;
  const raw = ["", ...splitLines(text)];
  const lexed = lex(raw, spec);
  const docstrings = spec.family === "python" ? docstringRanges(lexed) : [];
  lexed.masked = withoutRanges(lexed.masked, docstrings);
  const structure = buildStructure(spec, lexed);
  return {
    path, spec, raw, lexed, structure, docstrings, isTest: isTestPath(path),
    get masked() { return this.lexed.masked; },
    get lang() { return this.spec.name; },
    get lineCount() { return this.raw.length - 1; },
  };
}
