import fs from "node:fs";
import path from "node:path";
import { specsFor } from "./hookspec.mjs";
import { print, runMain } from "./util.mjs";

const INVALID_EXIT = 3;
const USAGE = "Usage: settings_merge.mjs [--dry-run] <settings.json> <group,group,...>";

function load(file) {
  if (!fs.existsSync(file) || !fs.statSync(file).size) return {};
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function registered(entries, command) {
  return entries.some((entry) => (entry.hooks ?? []).some((hook) => hook.command === command));
}

function addSpec(data, spec) {
  data.hooks ??= {};
  const entries = (data.hooks[spec.event] ??= []);
  if (registered(entries, spec.command)) return false;
  let group = entries.find((entry) => (entry.matcher ?? null) === spec.matcher);
  if (!group) {
    group = spec.matcher === null ? { hooks: [] } : { matcher: spec.matcher, hooks: [] };
    entries.push(group);
  }
  const hook = { type: "command", command: spec.command };
  if (spec.timeout) hook.timeout = spec.timeout;
  group.hooks.push(hook);
  return true;
}

function write(file, data) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(data, null, 2) + "\n");
}

export function mergeSettings(file, specs, dryRun = false) {
  const existed = fs.existsSync(file);
  let data;
  try {
    data = load(file);
  } catch {
    return { status: "invalid", missing: specs.map((spec) => spec.command) };
  }
  const missing = specs.filter((spec) => addSpec(data, spec)).map((spec) => spec.command);
  if (!missing.length) return { status: "skip", missing: [] };
  if (!dryRun) write(file, data);
  return { status: existed ? "merge" : "create", missing };
}

export function main(argv) {
  if (argv.includes("-h") || argv.includes("--help")) {
    print(USAGE);
    return 0;
  }
  const dryRun = argv.includes("--dry-run");
  const args = argv.filter((arg) => arg !== "--dry-run");
  const names = (args[1] ?? "").split(",").filter(Boolean);
  const result = mergeSettings(args[0], specsFor(names), dryRun);
  print(JSON.stringify(result));
  return result.status === "invalid" ? INVALID_EXIT : 0;
}

runMain(import.meta.url, main);
