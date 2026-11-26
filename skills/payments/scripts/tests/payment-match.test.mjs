import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), "..", "payment-match.mjs");
const EXPECT = { recipient: "Example Plumbing", amount: "120.50", purpose: "Faucet repair" };

const exec = (...args) => spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
const run = (expect, actual) => exec("--expect", JSON.stringify(expect), "--actual", JSON.stringify(actual));

test("match numeric amount", () => {
  const r = run(EXPECT, { ...EXPECT, amount: 120.5 });
  assert.deepEqual([r.status, JSON.parse(r.stdout).ok], [0, true]);
});

test("amount formats", () => {
  assert.equal(run(EXPECT, { ...EXPECT, amount: "$120.5" }).status, 0);
  assert.equal(run(EXPECT, { ...EXPECT, amount: "0120.500" }).status, 0);
  assert.equal(run({ ...EXPECT, amount: "1,000" }, { ...EXPECT, amount: 1000 }).status, 0);
  assert.equal(run(EXPECT, { ...EXPECT, amount: "abc" }).status, 1);
});

test("mismatch names only", () => {
  const r = run(EXPECT, { ...EXPECT, amount: "99.00", purpose: "Other" });
  assert.equal(r.status, 1);
  assert.deepEqual(JSON.parse(r.stdout).mismatch, ["amount", "purpose"]);
  for (const secret of ["Example Plumbing", "120.50", "99.00", "Faucet", "Other"]) {
    assert.ok(!(r.stdout + r.stderr).includes(secret));
  }
});

test("missing field is mismatch", () => {
  const r = run(EXPECT, { recipient: "Example Plumbing", amount: "120.50" });
  assert.deepEqual(JSON.parse(r.stdout).mismatch, ["purpose"]);
});

test("recipient exact case", () => {
  assert.deepEqual(JSON.parse(run(EXPECT, { ...EXPECT, recipient: "example plumbing" }).stdout).mismatch, ["recipient"]);
});

test("file inputs", () => {
  const dir = mkdtempSync(join(tmpdir(), "pm-"));
  const p = join(dir, "e.json");
  writeFileSync(p, JSON.stringify(EXPECT));
  try {
    assert.equal(exec("--expect", p, "--actual", p).status, 0);
  } finally {
    rmSync(dir, { recursive: true });
  }
});

test("bad input does not echo", () => {
  const r = exec("--expect", "{secret-value", "--actual", "{}");
  assert.equal(r.status, 2);
  assert.ok(!(r.stdout + r.stderr).includes("secret-value"));
});
