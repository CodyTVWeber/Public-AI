import { Scanner } from "./lexer.mjs";

export function splitLines(text) {
  const lines = text.replaceAll("\r\n", "\n").replaceAll("\r", "\n").split("\n");
  if (lines.length && lines[lines.length - 1] === "") lines.pop();
  return lines;
}

export function lex(raw, spec) {
  const scanner = new Scanner(spec);
  const masked = [""];
  for (let number = 1; number < raw.length; number++) masked.push(scanner.feed(raw[number], number));
  for (const comment of scanner.comments) {
    comment.standalone = masked[comment.line].slice(0, comment.col).trim() === "";
  }
  return { raw, masked, comments: scanner.comments, strings: scanner.strings, triples: scanner.triples };
}
