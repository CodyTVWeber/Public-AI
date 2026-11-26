import fs from "node:fs";
import path from "node:path";
import { blockEntries, blockNeeded, writeBlock } from "./exclude.mjs";
import { SKILL_DIR } from "./sources.mjs";
import { SKILL_FILE, SOURCE_HINT, skillNames, sourceDir, validSet } from "./skills_sets.mjs";
import { isFile, lexists, print, printErr, realpath, runMain } from "./util.mjs";

const LINK_DIR = ".claude/skills";
const EXCLUDE_TAG = "skills";
const NO_SOURCE_EXIT = 3;
const USAGE = `Usage: link-skills.sh <target> [--skills-from PATH] [--skills SET] [--force] [--dry-run]

Symlinks skills from a Public-AI clone into <target>/.claude/skills/<name> (absolute-path links) and adds one
.git/info/exclude entry per link (.claude/skills/<name>), so the links stay local and uncommitted while the
team's own skills in that directory stay visible. Entries for removed links are dropped on the next run.
  --skills-from PATH  clone to link from (default: $PUBLIC_AI_DIR; no other default)
  --skills SET        core (default: write-plan, align, implement, review, watch, plan-implement-review-watch, plus support skills plan-implement-review, verify-change, monitor, review-*),
                      core+aliases (core plus the one-line aliases, apirw, apirwm and code-review), all (every skill dir with a SKILL.md), none,
                      or a comma list of skill names
  --force             replace a link that points elsewhere (a real directory is never replaced)
  --dry-run           report only
Missing names and directories without a SKILL.md are skipped with a warning.
Stdout: JSON {source, links:[{name, status}], warnings[]}; status: create, same, replace, conflict, skipped.
Exit: 0 ok, 2 usage, 3 no source clone or not a git repo`;

function isLink(file) {
  try {
    return fs.lstatSync(file).isSymbolicLink();
  } catch {
    return false;
  }
}

function linkState(dest, target, force) {
  if (!lexists(dest)) return "create";
  if (!isLink(dest)) return "conflict";
  if (fs.readlinkSync(dest) === target) return "same";
  return force ? "replace" : "conflict";
}

export function planLinks(places, names, force) {
  const [root, source] = places;
  const links = [];
  const warnings = [];
  for (const name of names) {
    const src = path.join(source, "skills", name);
    if (!isFile(path.join(src, SKILL_FILE))) {
      warnings.push("skipped " + name + ": no " + SKILL_FILE + " in " + src);
      links.push({ name, status: "skipped" });
      continue;
    }
    const dest = path.join(root, LINK_DIR, name);
    links.push({ name, status: linkState(dest, src, force), src, dest });
  }
  return [links, warnings];
}

function createLink(link) {
  fs.mkdirSync(path.dirname(link.dest), { recursive: true });
  if (isLink(link.dest)) fs.unlinkSync(link.dest);
  fs.symlinkSync(link.src, link.dest);
}

function excludeEntries(root, links) {
  const wanted = new Set(links.filter((link) => ["create", "same", "replace"].includes(link.status)).map((link) => link.name));
  const prefix = LINK_DIR + "/";
  const previous = blockEntries(root, EXCLUDE_TAG).filter((line) => line.startsWith(prefix)).map((line) => line.slice(prefix.length));
  const kept = previous.filter((name) => lexists(path.join(root, LINK_DIR, name)));
  return [...new Set([...wanted, ...kept])].sort().map((name) => prefix + name);
}

export function excludeNeeded(root, links) {
  return blockNeeded(root, EXCLUDE_TAG, excludeEntries(root, links));
}

export function applyLinks(root, links) {
  for (const link of links) if (["create", "replace"].includes(link.status)) createLink(link);
  writeBlock(root, EXCLUDE_TAG, excludeEntries(root, links));
}

function parseArgs(argv) {
  const opts = { target: null, from: null, set: "core", force: false, dry: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--skills-from") opts.from = argv[++i] ?? null;
    else if (arg === "--skills") opts.set = argv[++i] ?? null;
    else if (arg === "--force") opts.force = true;
    else if (arg === "--dry-run") opts.dry = true;
    else if (arg.startsWith("-")) return null;
    else opts.target = arg;
  }
  return opts.target && opts.set && validSet(opts.set) ? opts : null;
}

export function main(argv) {
  if (argv.includes("-h") || argv.includes("--help")) {
    print(USAGE);
    return 0;
  }
  const opts = parseArgs(argv);
  if (opts === null) {
    printErr(USAGE);
    return 2;
  }
  const source = sourceDir(opts.from);
  const root = realpath(opts.target);
  if (source === null || !fs.existsSync(path.join(root, ".git"))) {
    printErr("link-skills: no Public-AI clone (" + SOURCE_HINT + ") or target is not a git repo");
    return NO_SOURCE_EXIT;
  }
  const [links, warnings] = planLinks([root, source], skillNames(SKILL_DIR, source, opts.set), opts.force);
  if (!opts.dry) applyLinks(root, links);
  const shown = links.map(({ name, status }) => ({ name, status }));
  print(JSON.stringify({ source, links: shown, warnings }));
  for (const warning of warnings) printErr("link-skills: " + warning);
  return 0;
}

runMain(import.meta.url, main);
