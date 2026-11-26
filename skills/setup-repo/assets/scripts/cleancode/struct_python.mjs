import { makeBlock, makeFunction, updateDepth } from "./model.mjs";
import { extractParams } from "./params.mjs";
import { balancedInner, statements } from "./parens.mjs";

const DEF = /^(?:async\s+)?def\s+(?<name>\w+)\s*(?=\()/;
const CONTROL = /^(?:async\s+)?(?<word>if|elif|else|for|while|try|except|finally|match)\b/;
const ONE_LINE_EMPTY = /^except\b[^:]*:\s*(?:pass|\.\.\.)\s*$/;
const KIND_OF = { try: "try", except: "catch", finally: "finally" };
const TRY_KINDS = new Set(["try", "catch", "finally"]);
const COUNTED = new Set([...TRY_KINDS, "ctl"]);
const EMPTY_BODIES = new Set(["pass", "..."]);

class PythonBuilder {
  constructor() {
    this.stack = [];
    this.functions = [];
    this.blocks = [];
    this.previousEnd = 0;
  }

  run(items) {
    for (const item of items) this.statement(item);
    this.popWhile(() => true);
    return { functions: this.functions, blocks: this.blocks };
  }

  statement(item) {
    this.popWhile((frame) => frame.indent >= item.indent);
    if (this.stack.length) this.stack[this.stack.length - 1].stmts.push(item.text);
    if (!this.openDef(item)) this.openControl(item);
    this.previousEnd = item.end;
  }

  popWhile(condition) {
    while (this.stack.length && condition(this.stack[this.stack.length - 1])) this.applyPop(this.stack.pop());
  }

  applyPop(frame) {
    if (frame.kind === "fn") {
      frame.func.end = this.previousEnd;
      return;
    }
    if (!TRY_KINDS.has(frame.kind)) return;
    const empty = frame.kind === "catch" && frame.stmts.every((text) => EMPTY_BODIES.has(text));
    this.blocks.push(makeBlock({ kind: frame.kind, start: frame.start, end: this.previousEnd, empty, owner: this.owner() }));
  }

  owner() {
    for (let index = this.stack.length - 1; index >= 0; index--) {
      if (this.stack[index].kind === "fn") return this.stack[index].func;
    }
    return null;
  }

  openDef(item) {
    const found = DEF.exec(item.text);
    if (!found) return false;
    const inner = balancedInner(item.text, found[0].length);
    const func = makeFunction({ name: found.groups.name, start: item.start, headerEnd: item.end, end: item.end });
    func.params = extractParams(inner ? inner[0] : "", "python");
    this.functions.push(func);
    this.stack.push({ indent: item.indent, kind: "fn", start: item.start, func, stmts: [] });
    return true;
  }

  openControl(item) {
    const found = CONTROL.exec(item.text);
    if (!found) return;
    if (ONE_LINE_EMPTY.test(item.text)) {
      this.blocks.push(makeBlock({ kind: "catch", start: item.start, end: item.end, empty: true, owner: this.owner() }));
      return;
    }
    if (!item.text.endsWith(":")) return;
    const kind = KIND_OF[found.groups.word] || "ctl";
    this.stack.push({ indent: item.indent, kind, start: item.start, func: null, stmts: [] });
    this.recordDepth(item);
  }

  recordDepth(item) {
    let depth = 0;
    for (let index = this.stack.length - 1; index >= 0; index--) {
      const frame = this.stack[index];
      if (frame.kind === "fn") return updateDepth(frame.func, [depth, item.start]);
      if (COUNTED.has(frame.kind)) depth += 1;
    }
    return undefined;
  }
}

function continuationLines(triples) {
  const lines = new Set();
  for (const [start, , end] of triples) for (let line = start + 1; line <= end; line++) lines.add(line);
  return lines;
}

export function buildPython(masked, triples) {
  return new PythonBuilder().run(statements(masked, continuationLines(triples)));
}
