#!/usr/bin/env node
import { parseArgs } from "node:util";

const DESCRIPTION = `Usage: event-backtime.mjs --start ISO --buffer-min N --drive-min N --load-min N --getready-min N [--prep-min N] [--stated LIST] [--text]
Work backward from an event start to a chronological schedule.
Steps (earliest first): prep (optional), get-ready, load, depart, arrive, event start.
Durations are labeled recommendation unless named in --stated (comma list of
buffer, drive, load, getready, prep); the drive duration is labeled estimate otherwise.
Default stdout is JSON; --text prints a table instead. Times keep the --start offset, if any.
--start takes ISO 8601 (for example 2026-01-02T14:30). Exit: 0 ok, 2 usage.`;

const DURATIONS = ["prep", "getready", "load", "drive", "buffer"];
const STEPS = [["buffer", "Arrive"], ["drive", "Depart"], ["load", "Load"], ["getready", "Get ready"], ["prep", "Prep"]];
const ISO = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2})(?::(\d{2})(?::(\d{2})(?:[.,](\d{1,6}))?)?)?)?(Z|[+-]\d{2}(?::?\d{2})?)?$/i;

const pad = (n, w = 2) => String(n).padStart(w, "0");

function usage(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

function normalizeOffset(raw) {
  if (!raw || /^z$/i.test(raw)) return raw ? "+00:00" : "";
  const digits = raw.slice(1).replace(":", "");
  return `${raw[0]}${digits.slice(0, 2)}:${digits.slice(2, 4) || "00"}`;
}

function parseStart(text) {
  const m = ISO.exec(text);
  if (!m) return null;
  const [y, mo, d, h, mi, s] = m.slice(1, 7).map((x) => Number(x ?? 0));
  const micros = m[7] ? Number(m[7].padEnd(6, "0")) : 0;
  const ms = Date.UTC(y, mo - 1, d, h, mi, s);
  const check = new Date(ms);
  if (check.getUTCMonth() !== mo - 1 || check.getUTCDate() !== d || h > 23 || mi > 59 || s > 59) return null;
  return { ms, micros, offset: normalizeOffset(m[8] ?? "") };
}

function format(ms, micros, offset) {
  const d = new Date(ms);
  const date = `${pad(d.getUTCFullYear(), 4)}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
  const time = `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
  const frac = micros ? `.${pad(micros, 6)}` : "";
  return { time: `${date}T${time}:${pad(d.getUTCSeconds())}${frac}${offset}`, clock: time };
}

function build(start, minutes, stated) {
  const label = (name) => (stated.has(name) ? "stated" : name === "drive" ? "estimate" : "recommendation");
  const steps = [{ step: "Event start", at: start.ms, minutes_to_next: 0, basis: "stated" }];
  let clock = start.ms;
  for (const [name, step] of STEPS) {
    if (name === "prep" && !minutes[name]) continue;
    clock -= minutes[name] * 60000;
    steps.push({ step, at: clock, minutes_to_next: minutes[name], basis: label(name) });
  }
  return steps.reverse().map(({ step, at, minutes_to_next, basis }) => {
    const { time, clock: hhmm } = format(at, start.micros, start.offset);
    return { step, time, clock: hhmm, minutes_to_next, basis };
  });
}

function parse() {
  const options = {
    start: { type: "string" }, "buffer-min": { type: "string" }, "drive-min": { type: "string" },
    "load-min": { type: "string" }, "getready-min": { type: "string" }, "prep-min": { type: "string", default: "0" },
    stated: { type: "string", default: "" }, text: { type: "boolean" }, help: { type: "boolean", short: "h" },
  };
  try {
    return parseArgs({ options, args: process.argv.slice(2) }).values;
  } catch (e) {
    return usage(`${DESCRIPTION}\n${e.message}`);
  }
}

function readMinutes(v) {
  const minutes = {};
  const sources = { buffer: v["buffer-min"], drive: v["drive-min"], load: v["load-min"], getready: v["getready-min"], prep: v["prep-min"] };
  for (const [name, raw] of Object.entries(sources)) {
    if (raw === undefined || !/^[+-]?\d+$/.test(raw.trim())) usage(`--${name === "getready" ? "getready" : name}-min must be an integer`);
    minutes[name] = Number(raw);
  }
  if (Object.values(minutes).some((n) => n < 0)) usage("durations must be >= 0");
  return minutes;
}

function main() {
  const v = parse();
  if (v.help) {
    console.log(DESCRIPTION);
    return;
  }
  if (v.start === undefined) usage("--start is required");
  const minutes = readMinutes(v);
  const start = parseStart(v.start);
  if (!start) usage("--start must be ISO 8601");
  const stated = new Set(v.stated.split(",").map((s) => s.trim()).filter(Boolean));
  if (![...stated].every((s) => DURATIONS.includes(s))) usage(`--stated accepts: ${DURATIONS.join(", ")}`);
  const schedule = build(start, minutes, stated);
  if (v.text) {
    console.log("| Time | Step | Basis |\n|---|---|---|");
    for (const r of schedule) console.log(`| ${r.clock} | ${r.step} | ${r.basis} |`);
  } else {
    console.log(JSON.stringify({ schedule }));
  }
}

main();
