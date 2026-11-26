import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

export const GIT_TIMEOUT_MS = 20000;

export function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", maxBuffer: 1 << 28, ...options });
  if (result.error) return null;
  return { status: result.status, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
}

export function gitOut(cwd, ...args) {
  const result = run("git", ["-C", cwd, ...args], { timeout: GIT_TIMEOUT_MS });
  return result && result.status === 0 ? result.stdout : "";
}

export function splitlines(text) {
  const lines = text.split(/\r\n|\r|\n/);
  if (lines.length && lines[lines.length - 1] === "") lines.pop();
  return lines;
}

export function readText(file) {
  try {
    return fs.readFileSync(file, "utf8");
  } catch {
    return null;
  }
}

export function exists(file) {
  return fs.existsSync(file);
}

export function lexists(file) {
  try {
    fs.lstatSync(file);
    return true;
  } catch {
    return false;
  }
}

export function isFile(file) {
  try {
    return fs.statSync(file).isFile();
  } catch {
    return false;
  }
}

export function isDir(file) {
  try {
    return fs.statSync(file).isDirectory();
  } catch {
    return false;
  }
}

export function isExecutable(file) {
  try {
    fs.accessSync(file, fs.constants.X_OK);
    return isFile(file);
  } catch {
    return false;
  }
}

export function realpath(file) {
  try {
    return fs.realpathSync(file);
  } catch {
    return path.resolve(file);
  }
}

export function fnmatch(name, pattern) {
  let source = "";
  for (let i = 0; i < pattern.length; i++) {
    const ch = pattern[i];
    if (ch === "*") source += ".*";
    else if (ch === "?") source += ".";
    else if (ch === "[" && pattern.indexOf("]", i + 2) > 0) {
      const end = pattern.indexOf("]", i + 2);
      const body = pattern.slice(i + 1, end).replace(/^!/, "^").replace(/\\/g, "\\\\");
      source += "[" + body + "]";
      i = end;
    } else source += ch.replace(/[.*+?^${}()|[\]\\/]/g, "\\$&");
  }
  return new RegExp("^" + source + "$", "s").test(name);
}

export function readJson(file) {
  const text = readText(file);
  if (text === null) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

export function relpath(target, base) {
  return path.relative(base, target);
}

export function isMain(url) {
  return process.argv[1] !== undefined && url === pathToFileURL(fs.realpathSync(process.argv[1])).href;
}

export function runMain(url, main) {
  if (isMain(url)) process.exit(main(process.argv.slice(2)) ?? 0);
}

export function print(text, fd = 1, end = "\n") {
  const data = Buffer.from(text + end);
  let offset = 0;
  while (offset < data.length) {
    try {
      offset += fs.writeSync(fd, data, offset);
    } catch (error) {
      if (error.code !== "EAGAIN") throw error;
    }
  }
}

export function printErr(text, end = "\n") {
  print(text, 2, end);
}

export function truthy(value) {
  if (Array.isArray(value)) return value.length > 0;
  if (value && typeof value === "object") return Object.keys(value).length > 0;
  return Boolean(value);
}
