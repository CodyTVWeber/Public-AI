import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), "..", "event-entry-lint.mjs");

const FULL = [
  "Picnic",
  "",
  "- **Address:** the venue address as stated by the source",
  "- **Logistics:** park at the north lot, bring chairs",
  "- **Confirmations:** unknown",
  "- **Official link:** https://venue.example.test",
  "- **Source-email link:** https://mail.example.test/m/1",
  "- **Searchable subject:** Picnic details",
  "",
].join("\n");

function lint(text) {
  const dir = mkdtempSync(join(tmpdir(), "entry-lint-"));
  const file = join(dir, "e.md");
  writeFileSync(file, text);
  try {
    const r = spawnSync(process.execPath, [SCRIPT, file], { encoding: "utf8" });
    return [r.status, JSON.parse(r.stdout)];
  } finally {
    rmSync(dir, { recursive: true });
  }
}

test("complete", () => {
  assert.deepEqual(lint(FULL), [0, { ok: true, missing: [] }]);
});

test("label styles", () => {
  const text = "Address: x\n**Logistics**: y\n* Confirmations:\nOfficial link: z\n> Source email link: w\nSearchable subject: s\n";
  assert.equal(lint(text)[0], 0);
});

test("missing listed", () => {
  const text = FULL.replace("- **Logistics:** park at the north lot, bring chairs\n", "").replace("Searchable subject", "Subject");
  const [code, out] = lint(text);
  assert.deepEqual([code, out.missing], [1, ["logistics", "searchable subject"]]);
});

test("label in prose does not count", () => {
  assert.equal(lint("Please send the address soon.\n")[0], 1);
});

test("unreadable", () => {
  assert.equal(spawnSync(process.execPath, [SCRIPT, "/nonexistent.md"]).status, 2);
});
