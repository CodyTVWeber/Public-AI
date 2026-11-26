import { basename } from "node:path";

const SEPARATORS = new Set("();|&\n");
const REDIRECT = /^[<>&|]*[<>][<>&|]*$/;
export const ASSIGN = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/s;
const HEREDOC_OPEN = /(?<!<)<<(?!<)-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1/g;
const SHELL_HEREDOC = /(^|[\s;&|(])(ba|z|da|k)?sh\b[^<]*<</;
const MASK = "$SUBST";
const BACKTICKS = /`([^`]*)`/g;
const PUNCTUATION = "();<>|&\n";
export const SHELLS = new Set(["sh", "bash", "zsh", "dash", "ksh", "fish"]);
export const KEYWORDS = new Set(["if", "then", "else", "elif", "while", "until", "do", "!", "{", "}", "time"]);
export const EXPORTERS = new Set(["export", "declare", "typeset", "local", "readonly"]);
export const WRAPPERS = {
  env: new Set(["-u", "-C", "-S", "--unset", "--chdir", "--split-string"]),
  sudo: new Set(["-u", "-g", "-h", "-p", "-C", "-U", "-r", "-t", "-T"]),
  nice: new Set(["-n"]),
  timeout: new Set(["-s", "-k"]),
  command: new Set(),
  exec: new Set(["-a"]),
  nohup: new Set(),
  xargs: new Set(["-I", "-n", "-P", "-L", "-d", "-E", "-s"]),
  setsid: new Set(),
};

export function stripHeredocs(text) {
  const out = [];
  const pending = [];
  for (const line of text.split("\n")) {
    if (pending.length) {
      if (heredocBodyLine(line, pending)) out.push(line);
      continue;
    }
    out.push(line);
    pending.push(...heredocOpeners(line));
  }
  return out.join("\n");
}

function heredocOpeners(line) {
  const runsShell = SHELL_HEREDOC.test(line);
  return [...line.matchAll(HEREDOC_OPEN)].map((match) => [match[2], runsShell]);
}

function heredocBodyLine(line, pending) {
  if (line.trim() === pending[0][0]) {
    pending.shift();
    return false;
  }
  return pending[0][1];
}

function dollarParenBody(text, start) {
  let depth = 1;
  let pos = start + 2;
  while (pos < text.length && depth) {
    depth += { "(": 1, ")": -1 }[text[pos]] || 0;
    pos += 1;
  }
  return [depth === 0 ? text.slice(start + 2, pos - 1) : text.slice(start + 2), pos];
}

export function substBodies(text) {
  const bodies = [...text.matchAll(BACKTICKS)].map((match) => match[1]);
  let pos = text.indexOf("$(");
  while (pos >= 0) {
    bodies.push(dollarParenBody(text, pos)[0]);
    pos = text.indexOf("$(", pos + 2);
  }
  return bodies;
}

export function maskSubstitutions(text) {
  let out = "";
  let pos = 0;
  while (pos < text.length) {
    const char = text[pos];
    if (char === "\\") {
      out += text.slice(pos, pos + 2);
      pos += 2;
    } else if (text.startsWith("$(", pos)) {
      out += MASK;
      pos = dollarParenBody(text, pos)[1];
    } else if (char === "`" && text.indexOf("`", pos + 1) > 0) {
      out += MASK;
      pos = text.indexOf("`", pos + 1) + 1;
    } else {
      out += char;
      pos += 1;
    }
  }
  return out;
}

function readQuoted(text, start) {
  const quote = text[start];
  let token = "";
  let i = start + 1;
  for (;;) {
    if (i >= text.length) throw new Error("No closing quotation");
    const char = text[i];
    if (char === quote) return [token, i + 1];
    if (quote === '"' && char === "\\") {
      if (i + 1 >= text.length) throw new Error("No escaped character");
      const next = text[i + 1];
      token += next === '"' || next === "\\" ? next : "\\" + next;
      i += 2;
    } else {
      token += char;
      i += 1;
    }
  }
}

function readWord(text, start, stops) {
  let token = "";
  let i = start;
  while (i < text.length && !stops.includes(text[i])) {
    const char = text[i];
    if (char === "'" || char === '"') {
      const [part, next] = readQuoted(text, i);
      token += part;
      i = next;
    } else if (char === "\\") {
      if (i + 1 >= text.length) throw new Error("No escaped character");
      token += text[i + 1];
      i += 2;
    } else {
      token += char;
      i += 1;
    }
  }
  return [token, i];
}

export function tokenize(text, punct = "") {
  const space = punct ? " \t\r" : " \t\r\n";
  const stops = space + punct;
  const tokens = [];
  let i = 0;
  while (i < text.length) {
    const char = text[i];
    if (space.includes(char)) {
      i += 1;
    } else if (punct.includes(char)) {
      let end = i;
      while (end < text.length && punct.includes(text[end])) end += 1;
      tokens.push(text.slice(i, end));
      i = end;
    } else {
      const [token, next] = readWord(text, i, stops);
      tokens.push(token);
      i = next;
    }
  }
  return tokens;
}

export function safeTokenize(text) {
  try {
    return tokenize(text, PUNCTUATION);
  } catch {
    return null;
  }
}

export function segments(tokens) {
  const result = [];
  let seg = [];
  for (const token of tokens) {
    if (token && [...token].every((c) => SEPARATORS.has(c))) {
      result.push(seg);
      seg = [];
    } else if (!REDIRECT.test(token)) {
      seg.push(token);
    }
  }
  result.push(seg);
  return result;
}

export function quoteWord(word) {
  if (word === "") return "''";
  if (/^[a-zA-Z0-9@%+=:,./-]+$/.test(word)) return word;
  return "'" + word.replaceAll("'", "'\"'\"'") + "'";
}

export function quoteAll(words) {
  return words.map(quoteWord).join(" ");
}

export function baseName(token) {
  return basename(token);
}
