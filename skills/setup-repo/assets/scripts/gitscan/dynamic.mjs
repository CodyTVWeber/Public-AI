import { basename } from "node:path";
import { SHELLS } from "./shellsyntax.mjs";
import { ASK_DYNAMIC, ASK_INTERPRETER } from "./tags.mjs";

const ACTIONS = "(commit|push|merge|cherry-pick|revert|send-pack|update-ref|commit-tree)";
const FORGE_ACTIONS = "(gh|glab)\\b[^\\n;&|]*(\\b(merge|create)\\b|-X\\s*(POST|PUT|PATCH|DELETE)|--method)";
const STRICT_TEXT = new RegExp("\\bgit\\b[^\\n;&|]*\\b" + ACTIONS + "\\b|\\b" + FORGE_ACTIONS, "i");
const LOOSE_TEXT = new RegExp("\\bgit\\b[\\s\\S]*\\b" + ACTIONS + "\\b|\\b" + FORGE_ACTIONS, "i");
const GIT_WORD = /\bgit\b/i;
const ANYWHERE_TEXT = new RegExp("\\b" + ACTIONS + "\\b", "i");
const KEYWORD_ARG = /^(commit|push|merge|cherry-pick|revert|rebase|am|send-pack|update-ref|commit-tree)$/;
const INTERPRETER = /^(sh|bash|zsh|dash|ksh|fish|csh|tcsh|python[0-9.]*|perl|ruby|node|nodejs|deno|bun|php|lua|awk|gawk|osascript|eval|source|\.)$/;
const INLINE_FLAG = /^-[a-zA-Z]*[ceEr]$|^--eval$|^--print$/;
const BRACE = /\{[^{}]*(,|\.\.)[^{}]*\}/;
const GLOB = /[*?[]/;
const STDIN_ARGS = new Set(["-", "-s", "/dev/stdin", "/dev/fd/0"]);
const AWKS = ["awk", "gawk"];

function isDynamic(word) {
  if (word === "[" || word === "[[") return false;
  return word.includes("$") || word.includes("`") || BRACE.test(word) || GLOB.test(word);
}

export function noteWord(words, source, found) {
  if (!isDynamic(words[0])) return;
  const named = ANYWHERE_TEXT.test(words[0]) || words.slice(1).some((arg) => KEYWORD_ARG.test(arg));
  if (named || (GIT_WORD.test(source) && ANYWHERE_TEXT.test(source))) found.add(ASK_DYNAMIC);
}

function inlineText(base, args) {
  if (base === "eval") return args.join(" ");
  if (AWKS.includes(base)) {
    const programs = args.filter((arg) => !arg.startsWith("-"));
    return programs.length ? programs[0] : null;
  }
  const pos = args.findIndex((arg) => INLINE_FLAG.test(arg));
  return pos < 0 ? null : args.slice(pos + 1).join(" ");
}

function readsStdin(base, args, source) {
  if (args.some((arg) => STDIN_ARGS.has(arg)) || args.every((arg) => arg.startsWith("-"))) return true;
  const escaped = base.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp("\\b" + escaped + "\\b[^\\n;&|]*<").test(source);
}

function isDynamicText(code) {
  return code.includes("$") || code.includes("`");
}

function noteInlineCode(code, source, found) {
  const text = isDynamicText(code) ? source : code;
  if (LOOSE_TEXT.test(text)) found.add(ASK_INTERPRETER);
}

export function noteDynamicCode(code, source, found) {
  if (isDynamicText(code)) noteInlineCode(code, source, found);
}

export function noteInterpreter(words, source, found) {
  const base = basename(words[0]).toLowerCase();
  if (!INTERPRETER.test(base)) return;
  const args = words.slice(1);
  const inline = SHELLS.has(base) ? null : inlineText(base, args);
  if (inline !== null) noteInlineCode(inline, source, found);
  else if (readsStdin(base, args, source) && STRICT_TEXT.test(source)) found.add(ASK_INTERPRETER);
}

export function noteStdinSubcommand(source, found) {
  if (ANYWHERE_TEXT.test(source)) found.add(ASK_INTERPRETER);
}
