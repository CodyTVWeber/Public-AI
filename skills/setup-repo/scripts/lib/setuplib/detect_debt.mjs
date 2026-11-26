import fs from "node:fs";
import { CODE_EXTENSIONS, extensionOf } from "./detect_stacks.mjs";
import { splitlines } from "./util.mjs";

const LONG_FILE_LINES = 400;
const DENSITY_MIN_LINES = 40;
const DENSITY_THRESHOLD = 0.25;
const MAX_FILES_SCANNED = 4000;
const HASH_COMMENT_EXTENSIONS = new Set(["py", "rb", "sh", "bash"]);
const SKIPPED_PARTS = ["/test/", "/tests/", "/generated/", "/vendor/", "/node_modules/", "/fixtures/"];
const SKIPPED_SUFFIXES = [".min.js", ".d.ts", ".lock"];

function isComment(line, ext) {
  const stripped = line.trim();
  if (HASH_COMMENT_EXTENSIONS.has(ext)) return stripped.startsWith("#") && !stripped.startsWith("#!");
  return ["//", "/*", "*"].some((prefix) => stripped.startsWith(prefix));
}

function scannable(name) {
  if (!CODE_EXTENSIONS.has(extensionOf(name)) || SKIPPED_SUFFIXES.some((suffix) => name.endsWith(suffix))) return false;
  return !SKIPPED_PARTS.some((part) => ("/" + name).includes(part));
}

function measure(repo, name) {
  const ext = extensionOf(name);
  const all = splitlines(repo.read(name));
  const lines = all.filter((line) => line.trim());
  const comments = lines.filter((line) => isComment(line, ext)).length;
  const dense = lines.length >= DENSITY_MIN_LINES && comments / lines.length >= DENSITY_THRESHOLD;
  return [all.length > LONG_FILE_LINES, dense];
}

function isRegular(repo, name) {
  try {
    return fs.statSync(repo.path(name)).isFile();
  } catch {
    return false;
  }
}

export function detectDebt(repo) {
  let longFiles = 0;
  let denseFiles = 0;
  const names = repo.files.filter((name) => scannable(name) && isRegular(repo, name));
  for (const name of names.slice(0, MAX_FILES_SCANNED)) {
    const [long, dense] = measure(repo, name);
    longFiles += long ? 1 : 0;
    denseFiles += dense ? 1 : 0;
  }
  return { files_over_400_lines: longFiles, files_with_comment_density_high: denseFiles,
    files_scanned: Math.min(names.length, MAX_FILES_SCANNED) };
}
