import { makeBlock, updateDepth } from "./model.mjs";

const TRY_KINDS = new Set(["try", "catch", "finally"]);
const COUNTED = new Set([...TRY_KINDS, "ctl"]);
const KIND_PATTERNS = [
  ["catch", /\bcatch\b/],
  ["finally", /\bfinally\b/],
  ["try", /\btry\b/],
  ["ctl", /\b(?:if|elseif|elif|else(?!\s*->)|for|foreach|while|do|switch|when|loop|match|guard|unless)\b/],
];
const SPACE = /\s/;

export class Walker {
  constructor(opens) {
    this.opens = opens;
    this.stack = [];
    this.blocks = [];
    this.prefix = [];
    this.parens = 0;
  }

  run(masked) {
    for (let number = 1; number < masked.length; number++) this.line(number, masked[number]);
    for (const frame of this.stack) this.applyFrameEnd(frame, masked.length - 1);
    return this.blocks;
  }

  line(number, text) {
    for (let col = 0; col < text.length; col++) {
      const char = text[col];
      if (char === "{") this.open(number, col);
      else if (char === "}") this.close(number);
      else this.other(char);
    }
    this.prefix.push(" ");
  }

  top() {
    return this.stack[this.stack.length - 1];
  }

  other(char) {
    if (char === "(") this.parens += 1;
    else if (char === ")") this.parens = Math.max(0, this.parens - 1);
    if (char === ";" && this.parens === 0) {
      this.prefix = [];
      return;
    }
    if (!SPACE.test(char) && this.stack.length) this.top().content = true;
    this.prefix.push(char);
  }

  open(number, col) {
    if (this.stack.length) this.top().content = true;
    const [kind, func] = this.classify(number, col);
    this.stack.push({ kind, start: number, func, content: false });
    this.prefix = [];
    if (COUNTED.has(kind)) this.recordDepth(number);
  }

  classify(number, col) {
    const func = this.opens.get(`${number},${col}`);
    if (func !== undefined) return ["fn", func];
    const text = this.prefix.join("");
    for (const [kind, pattern] of KIND_PATTERNS) {
      if (pattern.test(text)) return [kind, null];
    }
    return ["plain", null];
  }

  recordDepth(number) {
    let depth = 0;
    for (let index = this.stack.length - 1; index >= 0; index--) {
      const frame = this.stack[index];
      if (frame.kind === "fn") return updateDepth(frame.func, [depth, number]);
      if (COUNTED.has(frame.kind)) depth += 1;
    }
    return undefined;
  }

  close(number) {
    this.prefix = [];
    if (this.stack.length) this.applyFrameEnd(this.stack.pop(), number);
  }

  applyFrameEnd(frame, number) {
    if (frame.kind === "fn") frame.func.end = number;
    if (!TRY_KINDS.has(frame.kind)) return;
    const owner = [...this.stack].reverse().find((item) => item.kind === "fn");
    this.blocks.push(makeBlock({ kind: frame.kind, start: frame.start, end: number, empty: !frame.content, owner: owner ? owner.func : null }));
  }
}
