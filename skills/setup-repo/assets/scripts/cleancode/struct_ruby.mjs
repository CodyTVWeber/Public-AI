import { makeFunction, updateDepth } from "./model.mjs";
import { extractParams } from "./params.mjs";

const DEF = /^\s*def\s+(?:self\.)?(?<name>[\w?!=]+)\s*(?:\((?<paren>[^)]*)\)|(?<bare>[^\n#]*))?/;
const OPENER = /^\s*(?:(?<word>if|unless|while|until|case|begin|for|def|class|module)\b)/;
const ASSIGNED_OPENER = /=\s*(?<word>if|unless|case|begin|while)\b/;
const DO_BLOCK = /\bdo\s*(?:\|[^|]*\|)?\s*$/;
const END = /^\s*end\b/;
const COUNTED = new Set(["if", "unless", "while", "until", "case", "begin", "for"]);

function openerWord(text) {
  const found = OPENER.exec(text) || ASSIGNED_OPENER.exec(text);
  if (found) return found.groups.word;
  return DO_BLOCK.test(text) ? "do" : null;
}

class RubyBuilder {
  constructor() {
    this.stack = [];
    this.functions = [];
  }

  run(masked) {
    for (let number = 1; number < masked.length; number++) this.line(number, masked[number]);
    return { functions: this.functions, blocks: [] };
  }

  line(number, text) {
    if (END.test(text)) return this.close(number);
    const word = openerWord(text);
    if (word === "def") return this.openDef(number, text);
    if (word) return this.openControl(number, word);
    return undefined;
  }

  openDef(number, text) {
    const found = DEF.exec(text).groups;
    const func = makeFunction({ name: found.name, start: number, headerEnd: number, end: number });
    func.params = extractParams(found.paren || found.bare || "", "ruby");
    this.functions.push(func);
    this.stack.push({ word: "def", func });
  }

  openControl(number, word) {
    this.stack.push({ word, func: null });
    if (!COUNTED.has(word)) return;
    let depth = 0;
    for (let index = this.stack.length - 1; index >= 0; index--) {
      const frame = this.stack[index];
      if (frame.word === "def") return updateDepth(frame.func, [depth, number]);
      if (COUNTED.has(frame.word)) depth += 1;
    }
    return undefined;
  }

  close(number) {
    if (!this.stack.length) return;
    const frame = this.stack.pop();
    if (frame.word === "def") frame.func.end = number;
  }
}

export function buildRuby(masked) {
  return new RubyBuilder().run(masked);
}
