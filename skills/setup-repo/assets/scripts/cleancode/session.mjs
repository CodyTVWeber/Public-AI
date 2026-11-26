import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const TTL_SECONDS = 7 * 24 * 3600;
const DEFAULT_MAX_ENTRIES = 500;
const PREFIX = "cc-session-";
const SUFFIX = ".edited";
const UNSAFE = /[^A-Za-z0-9_-]/g;
const PRIVATE_MODE = 0o600;
const NAME_MAX = 80;

function maxEntries() {
  const raw = process.env.CC_SESSION_LOG_MAX || "";
  return /^\d+$/.test(raw) && parseInt(raw, 10) > 0 ? parseInt(raw, 10) : DEFAULT_MAX_ENTRIES;
}

function logDirectory() {
  return process.env.TMPDIR || "/tmp";
}

function logPath(payload) {
  let name = String(payload.session_id || "").replace(UNSAFE, "_").slice(0, NAME_MAX);
  if (!name) {
    const cwd = payload.cwd || process.cwd();
    name = "cwd-" + crypto.createHash("sha1").update(cwd).digest("hex").slice(0, 12);
  }
  return path.join(logDirectory(), PREFIX + name + SUFFIX);
}

function parseEntries(text) {
  const entries = [];
  for (const line of text.split("\n")) {
    const tab = line.indexOf("\t");
    const stamp = tab < 0 ? line : line.slice(0, tab);
    const file = tab < 0 ? "" : line.slice(tab + 1);
    if (/^\d+$/.test(stamp) && file) entries.push([parseInt(stamp, 10), file]);
  }
  return entries;
}

function readEntries(file) {
  try {
    return parseEntries(fs.readFileSync(file, "utf8"));
  } catch {
    return [];
  }
}

function fresh(entries, now) {
  return entries.filter(([stamp]) => now - stamp <= TTL_SECONDS);
}

function latestUnique(entries) {
  const seen = new Set();
  const kept = [];
  for (const entry of [...entries].reverse()) {
    if (seen.has(entry[1])) continue;
    seen.add(entry[1]);
    kept.push(entry);
  }
  return kept.reverse();
}

function format(entries) {
  return entries.map(([stamp, file]) => `${stamp}\t${file}\n`).join("");
}

function writeEntries(file, entries) {
  const temporary = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, format(entries), { mode: PRIVATE_MODE });
  fs.renameSync(temporary, file);
}

function appendEntry(file, entry) {
  const flags = fs.constants.O_WRONLY | fs.constants.O_APPEND | fs.constants.O_CREAT | (fs.constants.O_NOFOLLOW || 0);
  const descriptor = fs.openSync(file, flags, PRIVATE_MODE);
  try {
    fs.writeSync(descriptor, format([entry]));
  } finally {
    fs.closeSync(descriptor);
  }
}

function removeStaleLogs(directory, now) {
  let names;
  try {
    names = fs.readdirSync(directory);
  } catch {
    return;
  }
  for (const name of names) {
    if (!name.startsWith(PREFIX) || !name.endsWith(SUFFIX)) continue;
    const full = path.join(directory, name);
    if (now - fs.lstatSync(full).mtimeMs / 1000 > TTL_SECONDS) fs.unlinkSync(full);
  }
}

export function record(payload, edited) {
  const now = Math.floor(Date.now() / 1000);
  const file = logPath(payload);
  try {
    appendEntry(file, [now, edited]);
    const entries = readEntries(file);
    const kept = latestUnique(fresh(entries, now)).slice(-maxEntries());
    if (kept.length !== entries.length) writeEntries(file, kept);
    removeStaleLogs(logDirectory(), now);
  } catch {
    return;
  }
}

export function loggedPaths(payload) {
  const entries = fresh(readEntries(logPath(payload)), Math.floor(Date.now() / 1000));
  return latestUnique(entries).map(([, file]) => file).filter((file) => {
    try {
      return fs.statSync(file).isFile();
    } catch {
      return false;
    }
  });
}
