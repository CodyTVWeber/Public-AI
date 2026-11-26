const MAX_HEADER_LINES = 14;
const CONTINUATION = "\\";

export function balancedInner(text, openIndex) {
  let depth = 0;
  for (let index = openIndex; index < text.length; index++) {
    if (text[index] === "(") depth += 1;
    if (text[index] === ")") depth -= 1;
    if (depth === 0) return [text.slice(openIndex + 1, index), index];
  }
  return null;
}

export function matchParen(masked, position) {
  const [line, col] = position;
  const last = Math.min(masked.length - 1, line + MAX_HEADER_LINES);
  const chunk = masked.slice(line, last + 1).join("\n");
  const found = balancedInner(chunk, col);
  if (found === null) return null;
  const [inner, close] = found;
  const before = chunk.slice(0, close);
  const row = before.split("\n").length - 1;
  const column = close - (before.lastIndexOf("\n") + 1);
  return [inner.replaceAll("\n", " "), line + row, column];
}

function count(line, chars) {
  let total = 0;
  for (const char of line) if (chars.includes(char)) total += 1;
  return total;
}

function netBrackets(line) {
  return count(line, "([{") - count(line, ")]}");
}

function indentOf(line) {
  return line.length - line.trimStart().length;
}

function currentContinues(current) {
  return current !== null && current.text.endsWith(CONTINUATION);
}

export function statements(masked, continuation) {
  const result = [];
  let depth = 0;
  let current = null;
  for (let number = 1; number < masked.length; number++) {
    const line = masked[number];
    if (!line.trim()) continue;
    if (current !== null && (depth > 0 || continuation.has(number) || currentContinues(current))) {
      current.end = number;
      current.text += " " + line.trim();
    } else {
      current = { start: number, end: number, indent: indentOf(line), text: line.trim() };
      result.push(current);
    }
    depth = Math.max(0, depth + netBrackets(line));
  }
  return result;
}
