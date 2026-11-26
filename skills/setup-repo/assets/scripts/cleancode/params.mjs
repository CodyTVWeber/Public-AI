import { makeParam } from "./model.mjs";

const IDENT = /[A-Za-z_$][\w$]*/g;
const BOOL_NAME = /^(?:is|has|should|enable)(?:[A-Z_]|$)/;
const BOOL_TYPES = new Set(["boolean", "bool"]);
const BOOL_DEFAULTS = new Set(["true", "false", "True", "False"]);
const RECEIVERS = new Set(["self", "cls", "this"]);
const DESTRUCTURE_START = "{[(";
const ARROW_CHARS = "-=";
const COMPARE_BEFORE = "=!<>";
const ALNUM = /[\p{L}\p{N}]/u;

function bracketDelta(text, index) {
  const char = text[index];
  if ("([{".includes(char)) return 1;
  if (")]}".includes(char)) return -1;
  const previous = index ? text[index - 1] : " ";
  if (char === "<") return ALNUM.test(previous) || previous === "_" || previous === ">" ? 1 : 0;
  if (char === ">" && !ARROW_CHARS.includes(previous)) return -1;
  return 0;
}

function splitTopLevel(text) {
  const parts = [];
  let current = "";
  let depth = 0;
  for (let index = 0; index < text.length; index++) {
    depth = Math.max(0, depth + bracketDelta(text, index));
    if (text[index] === "," && depth === 0) {
      parts.push(current);
      current = "";
    } else {
      current += text[index];
    }
  }
  parts.push(current);
  return parts.map((part) => part.trim()).filter(Boolean);
}

function plainSymbol(text, index) {
  const following = index + 1 < text.length ? text[index + 1] : " ";
  const previous = index ? text[index - 1] : " ";
  if (text[index] === "=") return !"=>".includes(following) && !COMPARE_BEFORE.includes(previous);
  return following !== ":" && previous !== ":";
}

function topIndex(text, wanted) {
  let depth = 0;
  for (let index = 0; index < text.length; index++) {
    if (depth === 0 && text[index] === wanted && plainSymbol(text, index)) return index;
    depth = Math.max(0, depth + bracketDelta(text, index));
  }
  return -1;
}

function untypedName(head, lang) {
  const idents = head.match(IDENT) || [];
  if (!idents.length) return ["", ""];
  if (lang === "go") return [idents[0], idents.slice(1).join(" ")];
  return [idents[idents.length - 1], idents.slice(0, -1).join(" ")];
}

function parseParam(raw, lang) {
  const text = raw.trim();
  const equals = topIndex(text, "=");
  const head = equals < 0 ? text : text.slice(0, equals).trim();
  const defaultText = equals < 0 ? "" : text.slice(equals + 1).trim();
  if (DESTRUCTURE_START.includes(head.slice(0, 1))) return makeParam({ name: "", typeText: "", defaultText, raw: text });
  const colon = topIndex(head, ":");
  if (colon < 0) {
    const [name, typeText] = untypedName(head, lang);
    return makeParam({ name, typeText, defaultText, raw: text });
  }
  const idents = head.slice(0, colon).match(IDENT) || [];
  return makeParam({ name: idents.length ? idents[idents.length - 1] : "", typeText: head.slice(colon + 1).trim(), defaultText, raw: text });
}

export function extractParams(inner, lang) {
  const parsed = splitTopLevel(inner).map((part) => parseParam(part, lang));
  const kept = parsed.filter((param) => !RECEIVERS.has(param.name));
  if (kept.length === 1 && kept[0].name === "void") return [];
  return kept;
}

export function isBoolFlag(param) {
  if (!BOOL_NAME.test(param.name)) return false;
  const words = param.typeText.replaceAll("?", "").split(/\s+/).filter(Boolean);
  if (!words.length) return true;
  return BOOL_TYPES.has(words[words.length - 1].toLowerCase()) || BOOL_DEFAULTS.has(param.default);
}
