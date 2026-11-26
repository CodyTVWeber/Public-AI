const FENCE = /^\s*(`{3,}|~{3,})\s*(\S*)/;
const HEADING = /^#{1,6}\s*(.+?)\s*#*\s*$/;

export function splitLines(text) {
  const lines = text.split(/\r\n|[\n\r\v\f\x1c-\x1e\x85\u2028\u2029]/);
  if (lines.at(-1) === "") lines.pop();
  return lines;
}

export function parseBody(body) {
  const blocks = [];
  const sections = new Map();
  let current = null;
  let fence = null;
  for (const line of splitLines(body)) {
    const m = FENCE.exec(line);
    if (m && fence === null) {
      fence = { lang: m[2].toLowerCase(), lines: [] };
    } else if (m && fence !== null && !m[2]) {
      blocks.push({ lang: fence.lang, text: fence.lines.join("\n") });
      fence = null;
    } else if (fence !== null) {
      fence.lines.push(line);
    } else if (HEADING.test(line)) {
      current = HEADING.exec(line)[1].toLowerCase();
      if (!sections.has(current)) sections.set(current, []);
    } else if (current !== null) {
      sections.get(current).push(line);
    }
  }
  const prose = body.replace(/^\s*(`{3,}|~{3,}).*?^\s*\1\s*$/gms, "");
  return { blocks, sections, prose };
}

export function section(sections, name) {
  for (const [key, lines] of sections) {
    if (key === name || key.startsWith(name)) return lines.join("\n");
  }
  return null;
}
