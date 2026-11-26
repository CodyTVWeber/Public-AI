import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), "..", "dedupe-tasks.mjs");

function run(newItems, existing) {
  const dir = mkdtempSync(join(tmpdir(), "dedupe-"));
  try {
    const paths = [["n.json", newItems], ["e.json", existing]].map(([name, data]) => {
      const p = join(dir, name);
      writeFileSync(p, JSON.stringify(data));
      return p;
    });
    const r = spawnSync(process.execPath, [SCRIPT, ...paths], { encoding: "utf8" });
    return [r.status, r.stdout ? JSON.parse(r.stdout) : null];
  } finally {
    rmSync(dir, { recursive: true });
  }
}

test("strings", () => {
  const [code, out] = run(["Call the vendor.", "Book room", "  book   ROOM!! "], ["call the vendor"]);
  assert.equal(code, 0);
  assert.deepEqual(out.new, ["Book room"]);
  assert.deepEqual(out.duplicates.map((d) => d.item), ["Call the vendor.", "  book   ROOM!! "]);
  assert.equal(out.duplicates[1].match, "Book room");
});

test("objects keep original", () => {
  const items = [{ action: "Send recap", owner: "A" }, { action: "Order chairs", owner: "B" }];
  const [, out] = run(items, [{ title: "send recap", id: 7 }]);
  assert.deepEqual(out.new, [items[1]]);
  assert.deepEqual(out.duplicates[0].match, { title: "send recap", id: 7 });
});

test("near match is new", () => {
  assert.deepEqual(run(["Send the recap today"], ["Send recap"])[1].new, ["Send the recap today"]);
});

test("bad input", () => {
  const dir = mkdtempSync(join(tmpdir(), "dedupe-"));
  const p = join(dir, "x.json");
  writeFileSync(p, "{}");
  try {
    assert.equal(spawnSync(process.execPath, [SCRIPT, p, p]).status, 2);
  } finally {
    rmSync(dir, { recursive: true });
  }
});
