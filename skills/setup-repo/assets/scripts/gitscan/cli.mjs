import { readFileSync } from "node:fs";
import { UNPARSED } from "./tags.mjs";
import { coarseFallback, commandTags } from "./scanner.mjs";

function readCommand(raw) {
  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    return [raw, null, true];
  }
  if (data === null || typeof data !== "object" || Array.isArray(data)) return [raw, null, true];
  if ((data.tool_name ?? "Bash") !== "Bash") return [null, null, false];
  return [(data.tool_input || {}).command || "", data.cwd ?? null, false];
}

export function main(argv) {
  const raw = argv.length ? JSON.stringify({ tool_input: { command: argv[0] } }) : readFileSync(0, "utf8");
  const [command, cwd, badJson] = readCommand(raw);
  if (command === null) return 0;
  const found = commandTags(command, cwd);
  if (badJson) found.add(UNPARSED);
  coarseFallback(command, found);
  const lines = [...found].sort().map((tag) => tag + "\n").join("");
  process.stdout.write(lines);
  return 0;
}
