#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { parseArgs } from "node:util";

const DESCRIPTION = `Usage: dedupe-tasks.mjs NEW.json EXISTING.json
Split new tasks into new and duplicates against an existing task list.
NEW.json and EXISTING.json are JSON arrays of strings or objects; an object's text is the
first of action, title, text, summary, name. Matching is exact after lowercasing, dropping
punctuation, and collapsing whitespace. A repeat inside NEW counts as a duplicate of its first.
Stdout: {"new": [...], "duplicates": [{"item", "match"}]}. Exit: 0 ok, 2 usage.`;

const KEYS = ["action", "title", "text", "summary", "name"];

function usage(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

function sortedJson(value) {
  return JSON.stringify(value, (_, v) =>
    v && typeof v === "object" && !Array.isArray(v) ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => (a < b ? -1 : 1))) : v);
}

function textOf(item) {
  if (typeof item === "string") return item;
  if (item && typeof item === "object" && !Array.isArray(item)) {
    const key = KEYS.find((k) => typeof item[k] === "string");
    if (key) return item[key];
  }
  return sortedJson(item);
}

function norm(text) {
  return text.toLowerCase().replace(/[^\p{L}\p{N}_\s]/gu, " ").replace(/\s+/g, " ").trim();
}

function load(path) {
  let data;
  try {
    data = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    usage(`cannot read JSON: ${path}`);
  }
  if (!Array.isArray(data)) usage(`not a JSON array: ${path}`);
  return data;
}

function main() {
  let positionals;
  try {
    const parsed = parseArgs({ allowPositionals: true, options: { help: { type: "boolean", short: "h" } } });
    if (parsed.values.help) {
      console.log(DESCRIPTION);
      return;
    }
    positionals = parsed.positionals;
  } catch (e) {
    usage(`${DESCRIPTION}\n${e.message}`);
  }
  if (positionals.length !== 2) usage(DESCRIPTION);
  const seen = new Map(load(positionals[1]).map((i) => [norm(textOf(i)), i]));
  const fresh = [];
  const duplicates = [];
  for (const item of load(positionals[0])) {
    const key = norm(textOf(item));
    if (seen.has(key)) {
      duplicates.push({ item, match: seen.get(key) });
    } else {
      seen.set(key, item);
      fresh.push(item);
    }
  }
  console.log(JSON.stringify({ new: fresh, duplicates }));
}

main();
