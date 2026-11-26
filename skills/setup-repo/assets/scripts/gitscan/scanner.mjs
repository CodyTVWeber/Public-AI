import * as dynamic from "./dynamic.mjs";
import * as forge from "./forge.mjs";
import * as gitparse from "./gitparse.mjs";
import {
  ASSIGN, EXPORTERS, KEYWORDS, SHELLS, WRAPPERS, baseName, maskSubstitutions, safeTokenize, segments,
  stripHeredocs, substBodies, tokenize,
} from "./shellsyntax.mjs";
import * as subcommands from "./subcommands.mjs";
import { ASK_UNKNOWN, DENY_HOOKSPATH, GATE_TAGS, UNPARSED } from "./tags.mjs";

const MAX_DEPTH = 4;
const NUMERIC_WRAPPERS = ["timeout", "nice"];
const EXEC_ENV = new Set(["GIT_EDITOR", "GIT_SEQUENCE_EDITOR", "GIT_PAGER", "GIT_EXTERNAL_DIFF", "GIT_SSH_COMMAND",
  "GIT_ASKPASS", "GIT_PROXY_COMMAND", "EDITOR", "VISUAL", "PAGER"]);
const EXEC_PRIMARIES = ["-exec", "-execdir", "-ok", "-okdir"];

function wrapperSpan(tail, base) {
  let n = 0;
  while (n < tail.length && (tail[n].startsWith("-") || (NUMERIC_WRAPPERS.includes(base) && /^\d/.test(tail[n])))) {
    n += WRAPPERS[base].has(tail[n]) && n + 1 < tail.length ? 2 : 1;
  }
  return n;
}

class Scanner {
  constructor(cwd, source) {
    this.found = new Set();
    this.cwd = cwd;
    this.source = source;
    this.xargs = false;
  }

  analyze(text, depth = 0) {
    if (depth > MAX_DEPTH) {
      this.found.add(UNPARSED);
      return;
    }
    text = stripHeredocs(text);
    for (const body of substBodies(text)) this.analyze(body, depth + 1);
    const tokens = safeTokenize(text);
    if (tokens === null) {
      this.found.add(UNPARSED);
      gitparse.fallbackTags(text, this.found);
      return;
    }
    for (const seg of segments(tokens)) this.scanSegment(seg, depth);
    this.scanDynamicWords(text);
  }

  scanDynamicWords(text) {
    for (const seg of segments(safeTokenize(maskSubstitutions(text)) || [])) {
      const words = seg.slice(this.skipPrefix(seg));
      if (words.length) dynamic.noteWord(words, this.source, this.found);
    }
  }

  skipPrefix(seg) {
    let i = 0;
    while (i < seg.length) {
      const token = seg[i];
      const base = baseName(token);
      if (ASSIGN.test(token)) {
        this.noteAssignment(token);
        i += 1;
      } else if (KEYWORDS.has(base)) {
        i += 1;
      } else if (Object.hasOwn(WRAPPERS, base)) {
        this.xargs = this.xargs || base === "xargs";
        i += 1 + wrapperSpan(seg.slice(i + 1), base);
      } else {
        break;
      }
    }
    return i;
  }

  scanSegment(seg, depth) {
    const start = this.skipPrefix(seg);
    if (start >= seg.length) return;
    const words = seg.slice(start);
    if (EXPORTERS.has(baseName(words[0]))) {
      for (const arg of words.slice(1)) this.noteAssignment(arg);
      return;
    }
    this.dispatch(words, depth);
  }

  dispatch(words, depth) {
    const args = words.slice(1);
    const base = baseName(words[0]).toLowerCase();
    for (const arg of args) this.noteAssignment(arg);
    if (base === "git") this.scanGit(args, depth);
    else if (base.startsWith("git-") && subcommands.KNOWN.has(base.slice(4))) this.scanGit([base.slice(4), ...args], depth);
    else if (SHELLS.has(base)) this.scanShellC(args, depth);
    else if (base === "eval") this.analyze(args.join(" "), depth + 1);
    else if (base === "find") this.scanFind(args, depth);
    else if (forge.BINS.includes(base)) forge.scan(args, this.found);
    dynamic.noteInterpreter(words, this.source, this.found);
  }

  noteAssignment(token) {
    gitparse.noteAssign(token, this.found);
    const match = ASSIGN.exec(token);
    if (match && EXEC_ENV.has(match[1])) this.analyze(match[2], 1);
  }

  scanFind(args, depth) {
    args.forEach((arg, pos) => {
      if (EXEC_PRIMARIES.includes(arg)) this.analyze(gitparse.quoteAll(args.slice(pos + 1)), depth + 1);
    });
  }

  scanShellC(args, depth) {
    for (let k = 0; k < args.length; k += 1) {
      const arg = args[k];
      if (arg.startsWith("-") && !arg.startsWith("--") && arg.slice(1).includes("c") && k + 1 < args.length) {
        this.analyze(args[k + 1], depth + 1);
        dynamic.noteDynamicCode(args[k + 1], this.source, this.found);
        return;
      }
    }
  }

  scanGit(args, depth) {
    const [i, cfg] = gitparse.splitGitArgs(args);
    if (i >= args.length) {
      if (this.xargs) dynamic.noteStdinSubcommand(this.source, this.found);
      return;
    }
    if (gitparse.hooksOverride(cfg)) this.found.add(DENY_HOOKSPATH);
    const call = { sub: args[i].toLowerCase(), cfg, rest: args.slice(i + 1) };
    for (const entry of cfg) {
      if (!entry.toLowerCase().startsWith("alias.")) this.analyze(entry.slice(entry.indexOf("=") + 1), depth + 1);
    }
    for (const command of subcommands.scan(call.sub, call.rest, this.found)) this.analyze(command, depth + 1);
    if (!subcommands.KNOWN.has(call.sub)) this.followAlias(call, depth);
  }

  followAlias(call, depth) {
    let value = gitparse.aliasFromConfig(call.sub, call.cfg);
    if (value === null && depth < MAX_DEPTH) value = gitparse.aliasFromGit(call.sub, this.cwd);
    if (value === null || depth >= MAX_DEPTH) this.found.add(ASK_UNKNOWN);
    else if (value.startsWith("!")) this.analyze(value.slice(1) + " " + gitparse.quoteAll(call.rest), depth + 1);
    else this.scanAliased(value, call, depth);
  }

  scanAliased(value, call, depth) {
    try {
      this.scanGit([...tokenize(value), ...call.rest], depth + 1);
    } catch {
      this.found.add(UNPARSED);
      this.found.add(ASK_UNKNOWN);
    }
  }
}

export function commandTags(command, cwd = null) {
  const scanner = new Scanner(cwd, command);
  scanner.analyze(command);
  return scanner.found;
}

export function coarseFallback(command, found) {
  if (found.has(UNPARSED) && ![...GATE_TAGS].some((tag) => found.has(tag))) gitparse.coarseTags(command, found);
}
