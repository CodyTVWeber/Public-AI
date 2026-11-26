import { makeFinding } from "./catalog.mjs";
import { ERROR, WARN } from "./model.mjs";

const TODO = /\b(?:TODO|FIXME|XXX)\b/;
const BANNER = /^(?:STATUS:|[=\-#*~_/]{4,})/;
const ALWAYS_ALLOWED = new RegExp(
  "^(?:SPDX-License-Identifier:|Copyright\\b|go:(?:build|generate|embed|linkname)\\b"
  + "|\\+build\\b|Code generated\\b|-\\*-|(?:en)?coding[:=]|frozen_string_literal:"
  + "|shellcheck\\s+(?:shell|source|source-path)=|/\\s*<reference\\b|eslint-enable\\b)");
const DIRECTIVE = new RegExp(
  "^(?:eslint-disable\\S*|@ts-[\\w-]+|noqa\\b|type:\\s*ignore|pylint:|pragma:|istanbul\\b"
  + "|prettier-ignore|nolint|shellcheck\\s+disable|NOSONAR|detekt:|rubocop:|swiftlint:|fmt:)");
const REASON = /\s--\s+\S*\w/;
const SHEBANG_LINE = 1;
const PREVIEW_LENGTH = 60;
const LABELS = {
  banner: "banner or STATUS line: ", "todo-marker": "TODO marker: ",
  "added-comment": "added comment: ", docstring: "docstring: ",
};

function pythonDocstringBlocks(src) {
  return src.docstrings.map(([start, end, attached]) => {
    const first = src.raw[start].trim().replace(/^["']+|["']+$/g, "").trim();
    const lines = Array.from({ length: end - start + 1 }, (_, index) => start + index);
    return { lines, texts: [first], attached };
  });
}

function isShebang(comment) {
  return comment.line === SHEBANG_LINE && comment.text.startsWith("!");
}

function groupComments(comments) {
  const blocks = [];
  let last = null;
  const ordered = [...comments].sort((a, b) => a.line - b.line || a.col - b.col);
  for (const comment of ordered) {
    if (isShebang(comment)) continue;
    const joins = last && comment.standalone && last.standalone && comment.line <= last.line + 1;
    if (joins) {
      blocks[blocks.length - 1].lines.push(comment.line);
      blocks[blocks.length - 1].texts.push(comment.text);
    } else {
      blocks.push({ lines: [comment.line], texts: [comment.text], attached: false });
    }
    last = comment;
  }
  return blocks;
}

function textAllowed(text, line) {
  if (!text) return true;
  if (line === SHEBANG_LINE && text.startsWith("!")) return true;
  if (ALWAYS_ALLOWED.test(text)) return true;
  return DIRECTIVE.test(text) && REASON.test(text);
}

function classify(block) {
  if (block.texts.some((text) => BANNER.test(text))) return "banner";
  if (TODO.test(block.texts.join("\n"))) return "todo-marker";
  const allowed = block.texts.every((text, index) => textAllowed(text, block.lines[index]));
  return allowed ? null : "added-comment";
}

function describe(rule, block) {
  const preview = (block.texts.find((text) => text) || "").slice(0, PREVIEW_LENGTH);
  return LABELS[rule] + preview;
}

function verdictOf(rule, block) {
  return rule === "added-comment" && block.attached ? ["docstring", WARN] : [rule, ERROR];
}

export function checkComments(ctx) {
  const blocks = [...groupComments(ctx.src.lexed.comments), ...pythonDocstringBlocks(ctx.src)];
  const findings = [];
  for (const block of blocks) {
    const touched = block.lines.filter((line) => ctx.change.has(line));
    const rule = touched.length ? classify(block) : null;
    if (!rule) continue;
    const verdict = verdictOf(rule, block);
    findings.push(makeFinding([ctx.src.path, touched[0]], verdict, describe(verdict[0], block)));
  }
  return findings;
}
