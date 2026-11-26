import fs from "node:fs";
import path from "node:path";
import { fileTargets } from "./filetargets.mjs";
import { GitError } from "./gitdiff.mjs";
import { exitCode, headline, renderHuman, warningsOf } from "./report.mjs";
import { analyzeAll } from "./runner.mjs";
import * as session from "./session.mjs";
import { fileOptions, trackedTargets } from "./targets.mjs";

const BLOCKING = 2;
const HOOK_OPTIONS = fileOptions({ skipIgnored: true, requireRepo: true });
const FIX_PROMPT = "Fix these before continuing (rules/clean-code.md and rules/ban-comments.md):";

export function readPayload() {
  let text = "";
  try {
    text = fs.readFileSync(0, "utf8");
  } catch {
    return {};
  }
  try {
    const data = JSON.parse(text);
    return data !== null && typeof data === "object" && !Array.isArray(data) ? data : {};
  } catch {
    return {};
  }
}

function adviceBody(event, text) {
  if (event === "PostToolUse") return { hookSpecificOutput: { hookEventName: event, additionalContext: text } };
  return { systemMessage: text };
}

function stopTargets(payload) {
  const logged = session.loggedPaths(payload);
  if (logged.length) return fileTargets(logged, HOOK_OPTIONS);
  return trackedTargets(payload.cwd || process.cwd());
}

function realpath(file) {
  try {
    return fs.realpathSync(file);
  } catch {
    return path.resolve(file);
  }
}

export class HookSession {
  constructor(config, out, err) {
    Object.assign(this, { config, out, err });
  }

  postToolUse(payload) {
    let file = (payload.tool_input || {}).file_path || "";
    if (!file) return 0;
    if (!path.isAbsolute(file)) file = path.join(payload.cwd || process.cwd(), file);
    const targets = fileTargets([file], HOOK_OPTIONS);
    if (targets.length) session.record(payload, realpath(file));
    return this.finish("PostToolUse", analyzeAll(targets, this.config));
  }

  stop(payload) {
    if (payload.stop_hook_active) return 0;
    let targets;
    try {
      targets = stopTargets(payload);
    } catch (error) {
      if (error instanceof GitError) return 0;
      throw error;
    }
    return this.finish("Stop", analyzeAll(targets, this.config));
  }

  finish(event, findings) {
    if (exitCode(findings)) {
      this.err.write(`${headline(findings)}\n${FIX_PROMPT}\n${renderHuman(findings)}\n`);
      return BLOCKING;
    }
    this.advise(event, warningsOf(findings));
    return 0;
  }

  advise(event, findings) {
    if (!findings.length) return;
    const text = `${headline(findings)}\n${renderHuman(findings)}`;
    this.out.write(JSON.stringify(adviceBody(event, text)) + "\n");
  }
}
