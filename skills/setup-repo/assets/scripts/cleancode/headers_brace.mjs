import { makeFunction } from "./model.mjs";
import { extractParams } from "./params.mjs";
import { matchParen } from "./parens.mjs";

const BLOCK = "block";
const ARROW = "arrow";
const CONTROL_WORDS = new Set(["if", "for", "while", "switch", "catch", "return", "else", "do", "try",
  "synchronized", "when", "with", "function", "await", "new", "typeof",
  "sizeof", "super", "this", "assert", "foreach", "using", "lock", "fixed",
  "unless", "match", "elseif", "throw", "guard", "defer", "yield", "case"]);
const NON_TYPE_WORDS = new Set(["return", "new", "else", "throw", "case", "yield", "await", "delete", "goto",
  "typeof", "in", "is", "as"]);
const MODIFIERS = "(?:public|private|protected|internal|static|final|abstract|synchronized|native"
  + "|virtual|override|sealed|unsafe|extern|inline|async|partial|new|operator"
  + "|default|const|readonly|constexpr|explicit|friend|export|get|set)";
const KEYWORD_FN = new RegExp(
  "\\b(?:fun|func|fn|def|function)\\b\\s*(?:[<\\[][^>\\]()]*[>\\]]\\s*)?"
  + "(?:\\([^)]*\\)\\s*)?(?:[\\w.<>?\\[\\]]+\\.)?(?<name>[A-Za-z_$][\\w$]*)\\s*"
  + "(?:[<\\[][^>\\](]*[>\\]]\\s*)?(?=\\()");
const JS_ARROW = /(?<name>[A-Za-z_$][\w$]*)\s*(?::\s*[^=;(]+?)?\s*=\s*(?:async\s+)?(?=\()/;
const JS_PROPERTY = /(?<name>[A-Za-z_$][\w$]*)\s*:\s*(?:async\s+)?(?=\()/;
const JS_METHOD = new RegExp("^\\s*(?:" + MODIFIERS + "\\s+)*(?<name>[A-Za-z_$][\\w$]*)\\s*(?:<[^>(]*>)?\\s*(?=\\()");
const TYPED_METHOD = new RegExp(
  "^\\s*(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:" + MODIFIERS + "\\s+)*"
  + "(?<type>(?:[\\w<>\\[\\]?.,*&:]+\\s+)+)[*&]*(?<name>[A-Za-z_]\\w*)\\s*(?=\\()");
const TYPED = [[TYPED_METHOD, BLOCK]];
const PATTERNS = {
  js: [[KEYWORD_FN, BLOCK], [JS_ARROW, ARROW], [JS_PROPERTY, ARROW], [JS_METHOD, BLOCK]],
  java: TYPED, cs: TYPED, c: TYPED, cpp: TYPED,
};
const DEFAULT_PATTERNS = [[KEYWORD_FN, BLOCK]];
const ARROW_TOKEN = "=>";
const EXPRESSION = "expression";
const AFTER_ARROW = "brace-after-arrow";
const NEXT_LINE = "next-line";
const LOOKAHEAD_LINES = 2;

function firstOf(text, chars) {
  const hits = [...chars].filter((char) => text.includes(char)).map((char) => text.indexOf(char));
  return hits.length ? Math.min(...hits) : -1;
}

function firstAssignment(text) {
  for (let index = 0; index < text.length; index++) {
    if (text[index] === "=" && !["=", ">"].includes(text.slice(index + 1, index + 2))) return index;
  }
  return -1;
}

function scanArrow(rest, arrow) {
  if (arrow < 0) return null;
  return rest.slice(arrow + ARROW_TOKEN.length).trim().startsWith("{") ? AFTER_ARROW : EXPRESSION;
}

function scanRest(rest, kind) {
  if (kind === ARROW) return scanArrow(rest, rest.indexOf(ARROW_TOKEN));
  const stop = firstOf(rest, "{;");
  const equals = firstAssignment(rest);
  if (stop >= 0 && (equals < 0 || stop < equals)) return rest[stop] === "{" ? "{" : null;
  return equals >= 0 ? EXPRESSION : NEXT_LINE;
}

function nextLineBrace(masked, line) {
  const last = Math.min(masked.length, line + 1 + LOOKAHEAD_LINES);
  for (let number = line + 1; number < last; number++) {
    const stripped = masked[number].trim();
    if (stripped) return stripped.startsWith("{") ? [number, masked[number].indexOf("{")] : null;
  }
  return null;
}

function findBody(masked, [line, col], kind) {
  const rest = masked[line].slice(col);
  const found = scanRest(rest, kind);
  if (found === null) return null;
  if (found === "{") return [line, col + rest.indexOf("{")];
  if (found === EXPRESSION) return EXPRESSION;
  if (found === AFTER_ARROW) return [line, col + rest.indexOf("{", rest.indexOf(ARROW_TOKEN))];
  return nextLineBrace(masked, line);
}

function acceptable(match) {
  if (CONTROL_WORDS.has(match.groups.name)) return false;
  const typeText = match.groups.type;
  return !typeText || !NON_TYPE_WORDS.has(typeText.trim().split(/\s+/)[0]);
}

function buildHeader(masked, hit, lang) {
  const [match, kind, line] = hit;
  const span = matchParen(masked, [line, match.index + match[0].length]);
  if (span === null) return null;
  const [inner, endLine, endCol] = span;
  const body = findBody(masked, [endLine, endCol + 1], kind);
  if (body === null) return null;
  const func = makeFunction({ name: match.groups.name, start: line, headerEnd: endLine, end: endLine });
  func.params = extractParams(inner, lang);
  return [func, body === EXPRESSION ? null : body];
}

function firstFunction(masked, number, lang) {
  for (const [pattern, kind] of PATTERNS[lang] || DEFAULT_PATTERNS) {
    const match = pattern.exec(masked[number]);
    if (match === null || !acceptable(match)) continue;
    const built = buildHeader(masked, [match, kind, number], lang);
    if (built !== null) return built;
  }
  return null;
}

export function detectHeaders(masked, lang) {
  const found = [];
  for (let number = 1; number < masked.length; number++) {
    if (!masked[number].trim()) continue;
    const built = firstFunction(masked, number, lang);
    if (built !== null) found.push(built);
  }
  return found;
}
