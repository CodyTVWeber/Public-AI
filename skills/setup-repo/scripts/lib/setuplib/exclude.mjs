import fs from "node:fs";
import path from "node:path";
import { readText, run } from "./util.mjs";

const LEGACY_ENTRIES = { skills: [".claude/skills/"] };

function excludeFile(root) {
  const out = run("git", ["-C", root, "rev-parse", "--git-path", "info/exclude"]);
  const found = out ? out.stdout.trim() : "";
  return found.startsWith("/") ? found : path.join(root, found);
}

function markers(tag) {
  return ["# ai-guardrails:" + tag + ":begin", "# ai-guardrails:" + tag + ":end"];
}

function readFile(file) {
  return readText(file) ?? "";
}

function findBlock(lines, tag) {
  const [begin, end] = markers(tag);
  if (!lines.includes(begin) || !lines.includes(end)) return null;
  return [lines.indexOf(begin), lines.indexOf(end)];
}

export function blockEntries(root, tag) {
  const lines = readFile(excludeFile(root)).split("\n");
  const span = findBlock(lines, tag);
  return span ? lines.slice(span[0] + 1, span[1]) : [];
}

function trimEndNewlines(text) {
  return text.replace(/\n+$/, "");
}

function render(text, tag, entries) {
  let lines = text.split("\n");
  const span = findBlock(lines, tag);
  const legacy = LEGACY_ENTRIES[tag] ?? [];
  const [begin, end] = markers(tag);
  const block = entries.length ? [begin, ...[...new Set(entries)].sort(), end] : [];
  if (span) lines = [...lines.slice(0, span[0]), ...block, ...lines.slice(span[1] + 1)];
  else if (block.length) lines = text.trim() ? [...trimEndNewlines(text).split("\n"), ...block] : block;
  lines = lines.filter((line) => !legacy.includes(line));
  const body = trimEndNewlines(lines.join("\n"));
  if (body === trimEndNewlines(text)) return text;
  return body ? body + "\n" : "";
}

export function blockNeeded(root, tag, entries) {
  const text = readFile(excludeFile(root));
  return render(text, tag, entries) !== text;
}

export function writeBlock(root, tag, entries) {
  const file = excludeFile(root);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const text = readFile(file);
  const updated = render(text, tag, entries);
  if (updated !== text) fs.writeFileSync(file, updated);
}
