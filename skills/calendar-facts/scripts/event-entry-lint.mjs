#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { parseArgs } from "node:util";

const DESCRIPTION = `Usage: event-entry-lint.mjs FILE
Check a calendar event entry carries every required label.
Required: Address, Logistics, Confirmations, Official link, Source-email link, Searchable subject.
A label counts when a line starts with it followed by a colon (bullets and bold allowed).
An empty or "unknown" value passes: unknown fields stay blank and say so.
Stdout: {"ok", "missing": [...]}. Exit: 0 ok, 1 labels missing, 2 usage.`;

const LABELS = {
  "address": "address",
  "logistics": "logistics",
  "confirmations": "confirmations?",
  "official link": "official[ -]link",
  "source-email link": "source[ -]e-?mail[ -]link",
  "searchable subject": "searchable[ -]subject",
};

function usage(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

function parse() {
  try {
    const { values, positionals } = parseArgs({
      allowPositionals: true,
      options: { help: { type: "boolean", short: "h" } },
    });
    if (values.help) {
      console.log(DESCRIPTION);
      process.exit(0);
    }
    if (positionals.length !== 1) usage(DESCRIPTION);
    return positionals[0];
  } catch (e) {
    return usage(e.message);
  }
}

function findMissing(text) {
  return Object.entries(LABELS)
    .filter(([, pat]) => !new RegExp(`^[\\s>*+-]*\\**\\s*${pat}\\s*(?::\\s*\\**|\\**\\s*:)`, "im").test(text))
    .map(([name]) => name);
}

function main() {
  const file = parse();
  let text;
  try {
    text = readFileSync(file, "utf8");
  } catch {
    usage(`cannot read: ${file}`);
  }
  const missing = findMissing(text);
  console.log(JSON.stringify({ ok: missing.length === 0, missing }));
  for (const name of missing) process.stderr.write(`missing: ${name}\n`);
  process.exit(missing.length ? 1 : 0);
}

main();
