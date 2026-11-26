export function sameBlock(src, pair) {
  const indent = indentWidth(src.masked[pair.left.start]);
  if (indentWidth(src.masked[pair.right.start]) !== indent) return false;
  const low = Math.min(pair.left.start, pair.right.start);
  const high = Math.max(pair.left.start, pair.right.start);
  for (let number = low + 1; number < high; number++) {
    const text = src.masked[number];
    if (text.trim() && indentWidth(text) < indent) return false;
  }
  return true;
}

const TAB_WIDTH = 4;

export function indentWidth(text) {
  let width = 0;
  for (const char of text) {
    if (char === " ") width += 1;
    else if (char === "\t") width += TAB_WIDTH;
    else break;
  }
  return width;
}
