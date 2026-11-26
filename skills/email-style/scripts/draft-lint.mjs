#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { parseArgs } from "node:util";
import { lint } from "./draft-lint-rules.mjs";

const DESCRIPTION = `Usage: draft-lint.mjs FILE [--profile email|output] [--config PATH] [--skip RULES] [--recipient-elsewhere]
Lint an email draft or agent output against the email-style rules.

Profiles: email (headers, greeting, opening length, closing, signature, phone plus the shared
checks) or output (banned phrases, emoji, time-zone labels, opening length only).
Stdout: JSON list of {"line", "rule"}. Exit: 0 clean, 1 violations, 2 usage.
Greeting, closings, signature and phone come from a config JSON, never from this repo:
  --config PATH, else $AI_SKILLS_EMAIL_CONFIG, else ~/.config/ai-skills/email-style.json
  keys: "greeting" (required greeting word), "closings" (accepted closing lines),
        "signature" (name line expected after the closing), "phone" (digits compared)
Without a config the greeting, closing, signature and phone checks are skipped with a warning on stderr.
--skip RULE[,RULE] drops rules by prefix (for example header,phone,tz).
--recipient-elsewhere allows time-zone labels.`;

const DEFAULT_CONFIG_PATH = `${homedir()}/.config/ai-skills/email-style.json`;

function usage(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

function loadConfig(path) {
  try {
    const data = JSON.parse(readFileSync(path || process.env.AI_SKILLS_EMAIL_CONFIG || DEFAULT_CONFIG_PATH, "utf8"));
    return data && typeof data === "object" && !Array.isArray(data) ? data : null;
  } catch {
    return null;
  }
}

function splitLines(text) {
  const lines = text.split(/\r\n|[\n\r\v\f\x1c-\x1e\x85\u2028\u2029]/);
  if (lines.at(-1) === "") lines.pop();
  return lines;
}

function readLines(path) {
  try {
    return splitLines(readFileSync(path, "utf8"));
  } catch {
    return usage(`cannot read: ${path}`);
  }
}

function parse() {
  const options = {
    profile: { type: "string", default: "email" },
    config: { type: "string" },
    skip: { type: "string", default: "" },
    "recipient-elsewhere": { type: "boolean" },
    help: { type: "boolean", short: "h" },
  };
  let parsed;
  try {
    parsed = parseArgs({ options, allowPositionals: true });
  } catch (e) {
    usage(`${DESCRIPTION}\n${e.message}`);
  }
  if (parsed.values.help) {
    console.log(DESCRIPTION);
    process.exit(0);
  }
  if (parsed.positionals.length !== 1) usage(DESCRIPTION);
  if (!["email", "output"].includes(parsed.values.profile)) usage("--profile must be email or output");
  return parsed;
}

function main() {
  const { values, positionals } = parse();
  const lines = readLines(positionals[0]);
  const config = values.profile === "email" ? loadConfig(values.config) : null;
  const skips = values.skip.split(",").filter(Boolean);
  const settings = [config, Boolean(values["recipient-elsewhere"])];
  const found = lint(lines, values.profile, settings).filter((v) => !skips.some((s) => v.rule.startsWith(s)));
  console.log(JSON.stringify(found));
  for (const v of found) process.stderr.write(`line ${v.line}: ${v.rule}\n`);
  process.exit(found.length ? 1 : 0);
}

main();
