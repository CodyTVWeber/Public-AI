import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { isDir, isFile, realpath } from "./util.mjs";

const MANIFEST_RELATIVE = ["assets", "skills-manifest.json"];
export const SKILL_FILE = "SKILL.md";
const SET_NAMES = ["core", "core+aliases", "all", "none"];
const NAME_PATTERN = /^[a-z0-9][a-z0-9-]*$/;
export const SOURCE_HINT = "set PUBLIC_AI_DIR to a Public-AI clone or pass --skills-from PATH";

export function validSet(value) {
  return SET_NAMES.includes(value) || value.split(",").every((name) => NAME_PATTERN.test(name));
}

function expandUser(file) {
  if (file === "~") return os.homedir();
  return file.startsWith("~/") ? path.join(os.homedir(), file.slice(2)) : file;
}

export function sourceDir(explicit) {
  const candidate = explicit || process.env.PUBLIC_AI_DIR;
  if (!candidate) return null;
  const expanded = expandUser(candidate);
  return isDir(path.join(expanded, "skills")) ? realpath(expanded) : null;
}

function readManifest(skillDir) {
  return JSON.parse(fs.readFileSync(path.join(skillDir, ...MANIFEST_RELATIVE), "utf8"));
}

function everySkill(source) {
  const base = path.join(source, "skills");
  return fs.readdirSync(base).filter((name) => isFile(path.join(base, name, SKILL_FILE))).sort();
}

export function skillNames(skillDir, source, nameSet) {
  if (nameSet === "none") return [];
  if (nameSet === "all") return everySkill(source);
  if (SET_NAMES.includes(nameSet)) {
    const manifest = readManifest(skillDir);
    const extra = nameSet === "core+aliases" ? manifest.aliases : [];
    return [...manifest.core, ...manifest.support, ...extra];
  }
  return nameSet.split(",").filter(Boolean);
}
