import { escapeRegExp, makeFunction, makeParam } from "./model.mjs";

const FUNCTION_A = /^(\s*)([A-Za-z_][\w:.-]*)\s*\(\s*\)\s*(.*)$/;
const FUNCTION_B = /^(\s*)function\s+([A-Za-z_][\w:.-]*)\s*(?:\(\s*\))?\s*(.*)$/;
const POSITIONAL = /\$\{?([1-9])/g;
const TOKEN = /(?:^|[;&|({]|\bthen\b|\bdo\b|\belse\b|\belif\b)\s*(?:(?<open>if|for|while|until|case)|(?<close>fi|done|esac))\b/g;

function matchHeader(number, line) {
  for (const pattern of [FUNCTION_B, FUNCTION_A]) {
    const found = pattern.exec(line);
    if (found && ["{", ""].includes(found[3].trim().slice(0, 1))) {
      return { start: number, indent: found[1], name: found[2], rest: found[3].trim() };
    }
  }
  return null;
}

function depthChanges(line) {
  return [...line.matchAll(TOKEN)].map((found) => (found.groups.open ? 1 : -1));
}

class ShellBuilder {
  constructor(raw, masked) {
    this.raw = raw;
    this.masked = masked;
  }

  run() {
    const functions = [];
    for (let number = 1; number < this.masked.length; number++) {
      const header = matchHeader(number, this.masked[number]);
      const end = header ? this.findEnd(header) : null;
      if (end !== null) functions.push(this.makeFunction(header, end));
    }
    return { functions, blocks: [] };
  }

  findEnd(header) {
    const rest = header.rest;
    if (rest.startsWith("{") && rest.endsWith("}") && rest.length > 1) return header.start;
    const closer = new RegExp("^" + escapeRegExp(header.indent) + "\\}");
    for (let number = header.start + 1; number < this.masked.length; number++) {
      if (closer.test(this.masked[number])) return number;
    }
    return null;
  }

  makeFunction(header, end) {
    const func = makeFunction({ name: header.name, start: header.start, headerEnd: header.start, end });
    func.params = this.positional(header.start, end);
    [func.maxDepth, func.depthLine] = this.depth(header.start, end);
    return func;
  }

  positional(start, end) {
    let highest = 0;
    for (let number = start + 1; number <= end; number++) {
      if (!this.masked[number].trim()) continue;
      for (const found of this.raw[number].matchAll(POSITIONAL)) highest = Math.max(highest, parseInt(found[1], 10));
    }
    return Array.from({ length: highest }, (_, index) => makeParam({ name: "$" + (index + 1), typeText: "", defaultText: "", raw: "" }));
  }

  depth(start, end) {
    let depth = 0;
    let best = [0, start];
    for (let number = start; number <= end; number++) {
      for (const change of depthChanges(this.masked[number])) {
        depth = Math.max(0, depth + change);
        if (depth > best[0]) best = [depth, number];
      }
    }
    return best;
  }
}

export function buildShell(raw, masked) {
  return new ShellBuilder(raw, masked).run();
}
