import { TRIPLE_LENGTH } from "./languages.mjs";

const HEREDOC = /(?<!<)<<(?!<)[-~]?\s*(['"]?)([A-Za-z_]\w*)\1/g;
const RUST_CHAR = /'(?:\\[^']*|[^'\\])'/y;
const WORD_START = " \t;|&(";
const BLOCK_NOISE = /^\*+/;
const ESCAPE = "\\";

export class Scanner {
  constructor(spec) {
    this.spec = spec;
    this.blockClose = null;
    this.segCol = 0;
    this.quote = null;
    this.strStart = [0, 0];
    this.strBuf = [];
    this.heredoc = null;
    this.lineBlockOpen = false;
    this.lineno = 0;
    this.line = "";
    this.cells = [];
    this.comments = [];
    this.strings = [];
    this.triples = [];
  }

  feed(line, lineno) {
    this.lineno = lineno;
    this.line = line;
    if (this.heredoc !== null) return this.heredocLine();
    if (this.inLineBlock()) return " ".repeat(line.length);
    this.cells = line.split("");
    let position = 0;
    while (position < line.length) position = this.step(position);
    this.endLine();
    this.detectHeredoc();
    return this.cells.join("");
  }

  mask(start, stop) {
    const end = Math.min(stop, this.cells.length);
    for (let index = start; index < end; index++) this.cells[index] = " ";
  }

  addComment(col, text) {
    this.comments.push({ line: this.lineno, col, text, standalone: true });
  }

  step(position) {
    if (this.blockClose !== null) return this.block(position);
    if (this.quote !== null) return this.string(position);
    return this.code(position);
  }

  code(position) {
    const line = this.line;
    if (line[position] === ESCAPE) return position + 2;
    if (this.spec.rustChars && line[position] === "'") return this.rustChar(position);
    const prefix = this.commentPrefix(position);
    if (prefix) return this.lineComment(position, prefix);
    const block = this.spec.block;
    if (block.length && line.startsWith(block[0], position)) {
      this.blockClose = block[1];
      this.segCol = position;
      return this.block(position + block[0].length);
    }
    const quote = this.quoteAt(position);
    return quote === null ? position + 1 : this.openString(position, quote);
  }

  rustChar(position) {
    RUST_CHAR.lastIndex = position;
    const found = RUST_CHAR.exec(this.line);
    if (!found) return position + 1;
    const end = position + found[0].length;
    this.mask(position + 1, end - 1);
    return end;
  }

  commentPrefix(position) {
    for (const prefix of this.spec.lineComments) {
      if (this.line.startsWith(prefix, position) && this.commentOk(position)) return prefix;
    }
    return null;
  }

  commentOk(position) {
    const before = position ? this.line[position - 1] : " ";
    if (this.spec.wordStartComment) return WORD_START.includes(before);
    if (this.spec.urlGuard) return before !== ":";
    return true;
  }

  lineComment(position, prefix) {
    this.addComment(position, this.line.slice(position + prefix.length).trim());
    this.mask(position, this.line.length);
    return this.line.length;
  }

  block(position) {
    const line = this.line;
    const close = line.indexOf(this.blockClose, position);
    const stop = close < 0 ? line.length : close;
    this.addComment(this.segCol, line.slice(position, stop).trim().replace(BLOCK_NOISE, "").trim());
    const end = close < 0 ? line.length : close + this.blockClose.length;
    this.mask(this.segCol, end);
    if (close >= 0) this.blockClose = null;
    return end;
  }

  quoteAt(position) {
    for (const triple of this.spec.triples) {
      if (this.line.startsWith(triple, position)) return triple;
    }
    const char = this.line[position];
    return this.spec.quotes.includes(char) ? char : null;
  }

  openString(position, quote) {
    this.quote = quote;
    this.strStart = [this.lineno, position];
    this.strBuf = [];
    return this.string(position + quote.length);
  }

  string(position) {
    const line = this.line;
    const raw = this.spec.raw.includes(this.quote);
    let cursor = position;
    while (cursor < line.length) {
      if (line[cursor] === ESCAPE && !raw) {
        cursor += 2;
        continue;
      }
      if (line.startsWith(this.quote, cursor)) return this.closeString(position, cursor);
      cursor += 1;
    }
    this.take(position, line.length);
    return line.length;
  }

  take(start, stop) {
    this.strBuf.push(this.line.slice(start, stop));
    this.mask(start, stop);
  }

  closeString(start, stop) {
    this.take(start, stop);
    const quote = this.quote;
    this.quote = null;
    const content = this.strBuf.join("");
    if (quote.length === TRIPLE_LENGTH) this.triples.push([this.strStart[0], this.strStart[1], this.lineno]);
    else if (content) this.strings.push([this.strStart[0], content]);
    return stop + quote.length;
  }

  endLine() {
    this.segCol = 0;
    if (this.quote === null || this.stringContinues()) return;
    this.quote = null;
  }

  stringContinues() {
    if (this.quote.length === TRIPLE_LENGTH || this.spec.multiline.includes(this.quote)) return true;
    return this.line.trimEnd().endsWith(ESCAPE);
  }

  inLineBlock() {
    if (!this.spec.lineBlock.length) return false;
    const [opener, closer] = this.spec.lineBlock;
    if (!this.lineBlockOpen && !this.line.startsWith(opener)) return false;
    this.lineBlockOpen = !this.line.startsWith(closer);
    this.addComment(0, this.line.trim());
    return true;
  }

  detectHeredoc() {
    if (!this.spec.heredoc || this.quote || this.blockClose) return;
    for (const found of this.line.matchAll(HEREDOC)) {
      if (this.cells[found.index] === "<") {
        this.heredoc = found[2];
        return;
      }
    }
  }

  heredocLine() {
    if (this.line.trim() === this.heredoc) this.heredoc = null;
    return " ".repeat(this.line.length);
  }
}
