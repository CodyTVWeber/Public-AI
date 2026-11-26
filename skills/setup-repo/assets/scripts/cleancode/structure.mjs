import { buildBrace } from "./struct_brace.mjs";
import { buildPython } from "./struct_python.mjs";
import { buildRuby } from "./struct_ruby.mjs";
import { buildShell } from "./struct_shell.mjs";

function countLogic(masked, func) {
  const last = Math.min(func.end, masked.length - 1);
  let total = 0;
  for (let number = func.start; number <= last; number++) if (masked[number].trim()) total += 1;
  return total;
}

function build(spec, lexed) {
  const masked = lexed.masked;
  if (spec.family === "python") return buildPython(masked, lexed.triples);
  if (spec.family === "shell") return buildShell(lexed.raw, masked);
  if (spec.family === "ruby") return buildRuby(masked);
  return buildBrace(masked, spec.name);
}

export function buildStructure(spec, lexed) {
  const structure = build(spec, lexed);
  for (const func of structure.functions) func.logic = countLogic(lexed.masked, func);
  return structure;
}
