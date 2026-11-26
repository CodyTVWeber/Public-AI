import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), "..", "event-backtime.mjs");
const BASE = ["--start", "2026-01-02T14:30", "--buffer-min", "10", "--drive-min", "25", "--load-min", "15", "--getready-min", "40"];

const run = (...args) => spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
const schedule = (...args) => JSON.parse(run(...args).stdout).schedule;

test("order and times", () => {
  const out = schedule(...BASE);
  assert.deepEqual(out.map((r) => r.step), ["Get ready", "Load", "Depart", "Arrive", "Event start"]);
  assert.deepEqual(out.map((r) => r.clock), ["13:00", "13:40", "13:55", "14:20", "14:30"]);
  assert.equal(out.at(-1).basis, "stated");
});

test("prep and basis", () => {
  const out = schedule(...BASE, "--prep-min", "10", "--stated", "buffer,drive");
  assert.equal(out[0].step, "Prep");
  const by = Object.fromEntries(out.map((r) => [r.step, r.basis]));
  assert.deepEqual([by.Arrive, by.Depart, by.Load], ["stated", "stated", "recommendation"]);
});

test("text table chronological", () => {
  const lines = run(...BASE, "--text").stdout.split("\n").filter(Boolean);
  assert.ok(lines[2].startsWith("| 13:00 | Get ready"));
  assert.ok(lines.at(-1).startsWith("| 14:30 | Event start"));
});

test("crosses midnight", () => {
  const out = schedule("--start", "2026-01-02T00:30", "--buffer-min", "10", "--drive-min", "25", "--load-min", "15", "--getready-min", "40");
  assert.ok(out[0].time.startsWith("2026-01-01T23:"));
});

test("keeps offset", () => {
  const out = schedule("--start", "2026-01-02T14:30-05:00", ...BASE.slice(2));
  assert.equal(out.at(-1).time, "2026-01-02T14:30:00-05:00");
});

test("usage", () => {
  assert.equal(run().status, 2);
  assert.equal(run("--start", "nonsense", ...BASE.slice(2)).status, 2);
  assert.equal(run(...BASE, "--stated", "bogus").status, 2);
});
