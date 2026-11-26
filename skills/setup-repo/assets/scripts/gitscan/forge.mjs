import { FORGE_WRITE, MR_CREATE } from "./tags.mjs";

export const BINS = ["gh", "glab"];
const WRITE_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);
const FIELD_FLAGS = new Set(["-f", "-F", "--field", "--raw-field", "--input"]);
const FIELD_PREFIXES = ["--field=", "--raw-field=", "--input="];
const METHOD_FLAGS = new Set(["-X", "--method"]);
const VALUE_FLAGS = new Set(["-R", "--repo", "--hostname"]);
const REQUEST_NOUNS = ["pr", "mr"];

function positional(args) {
  const words = [];
  let skip = false;
  for (const arg of args) {
    if (skip) skip = false;
    else if (VALUE_FLAGS.has(arg)) skip = true;
    else if (!arg.startsWith("-")) words.push(arg);
  }
  return words;
}

function isFieldFlag(arg) {
  if (FIELD_FLAGS.has(arg) || FIELD_PREFIXES.some((p) => arg.startsWith(p))) return true;
  return arg.length > 2 && ["-f", "-F"].includes(arg.slice(0, 2)) && !arg.startsWith("--");
}

function methodOf(args) {
  let method = null;
  args.forEach((arg, pos) => {
    if (METHOD_FLAGS.has(arg) && pos + 1 < args.length) method = args[pos + 1];
    else if (arg.startsWith("--method=")) method = arg.slice(arg.indexOf("=") + 1);
    else if (arg.startsWith("-X") && arg.length > 2) method = arg.slice(2);
  });
  return method;
}

function apiWrites(args) {
  if (args.includes("graphql")) return args.some((arg) => arg.toLowerCase().includes("mutation"));
  const method = methodOf(args);
  if (method !== null) return WRITE_METHODS.has(method.toUpperCase());
  return args.some(isFieldFlag);
}

export function scan(args, found) {
  const words = positional(args).slice(0, 2);
  const request = words.length === 2 && REQUEST_NOUNS.includes(words[0]);
  if (request && words[1] === "create") found.add(MR_CREATE);
  else if (request && words[1] === "merge") found.add(FORGE_WRITE);
  else if (words[0] === "api" && apiWrites(args)) found.add(FORGE_WRITE);
}
