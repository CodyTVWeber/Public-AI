export const ERROR = "error";
export const WARN = "warn";

export function makeFunction({ name, start, headerEnd, end }) {
  return { name, start, headerEnd, end, params: [], maxDepth: 0, depthLine: 0, logic: 0 };
}

export function makeParam({ name, typeText, defaultText, raw }) {
  return { name, typeText, default: defaultText, raw };
}

export function makeBlock({ kind, start, end, empty, owner }) {
  return { kind, start, end, empty, owner };
}

export function updateDepth(func, [depth, line]) {
  if (depth > func.maxDepth) {
    func.maxDepth = depth;
    func.depthLine = line;
  }
}

export function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function startsWithAny(text, prefixes) {
  return prefixes.some((prefix) => text.startsWith(prefix));
}
