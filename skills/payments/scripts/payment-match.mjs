#!/usr/bin/env node
import { readFileSync, statSync } from "node:fs";
import { parseArgs } from "node:util";

const DESCRIPTION = `Usage: payment-match.mjs --expect JSON|FILE --actual JSON|FILE
Compare an expected obligation with an actual receipt on recipient, amount, purpose.
--expect and --actual take a JSON object or a path to a JSON file, each with
recipient, amount, purpose. Strings match exactly after trimming; amounts match numerically.
Stdout: {"ok", "mismatch": [field names]}. Values are never printed.
Exit: 0 all match, 1 mismatch, 2 usage.`;

const FIELDS = ["recipient", "amount", "purpose"];
const NUMBER = /^([+-]?)(\d*)\.?(\d*)(?:e([+-]?\d+))?$/i;

function usage(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

function isFile(path) {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
}

function load(raw, flag) {
  let data;
  try {
    data = JSON.parse(isFile(raw) ? readFileSync(raw, "utf8") : raw);
  } catch {
    usage(`${flag} is not valid JSON or a readable JSON file`);
  }
  if (data === null || typeof data !== "object" || Array.isArray(data)) usage(`${flag} must be a JSON object`);
  return data;
}

function canonical(value) {
  const m = NUMBER.exec(String(value).replace(/,/g, "").replace(/^\$+/, "").trim());
  if (!m || !(m[2] + m[3])) return null;
  const digits = (m[2] + m[3]).replace(/^0+/, "");
  if (!digits) return "0";
  const exp = Number(m[4] ?? 0) - m[3].length;
  const trimmed = digits.replace(/0+$/, "");
  const sign = m[1] === "-" ? "-" : "";
  return `${sign}${trimmed}e${exp + digits.length - trimmed.length}`;
}

function same(field, a, b) {
  if (a === undefined || a === null || b === undefined || b === null) return false;
  if (field === "amount") {
    const x = canonical(a);
    return x !== null && x === canonical(b);
  }
  return String(a).trim() === String(b).trim();
}

function main() {
  let values;
  try {
    ({ values } = parseArgs({ options: { expect: { type: "string" }, actual: { type: "string" }, help: { type: "boolean", short: "h" } } }));
  } catch (e) {
    usage(`${DESCRIPTION}\n${e.message}`);
  }
  if (values.help) {
    console.log(DESCRIPTION);
    return;
  }
  if (values.expect === undefined || values.actual === undefined) usage("--expect and --actual are required");
  const expect = load(values.expect, "--expect");
  const actual = load(values.actual, "--actual");
  const mismatch = FIELDS.filter((f) => !same(f, expect[f], actual[f]));
  console.log(JSON.stringify({ ok: mismatch.length === 0, mismatch }));
  if (mismatch.length) process.stderr.write(`mismatch: ${mismatch.join(", ")}\n`);
  process.exit(mismatch.length ? 1 : 0);
}

main();
