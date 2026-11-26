import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, symlinkSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const DATES = join(HERE, "..", "weekend-dates.mjs");
const SHEET = join(HERE, "..", "sheet-check.sh");

function makePdf(path, { pages = 1, size = [612, 792], text = "Weekend list" } = {}) {
  const objs = new Map();
  const kids = Array.from({ length: pages }, (_, i) => `${3 + i * 2} 0 R`).join(" ");
  const font = 3 + pages * 2;
  objs.set(1, "<< /Type /Catalog /Pages 2 0 R >>");
  objs.set(2, `<< /Type /Pages /Kids [${kids}] /Count ${pages} >>`);
  for (let i = 0; i < pages; i++) {
    objs.set(3 + i * 2, `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${size[0]} ${size[1]}] /Contents ${4 + i * 2} 0 R /Resources << /Font << /F1 ${font} 0 R >> >> >>`);
    const stream = `BT /F1 12 Tf 72 700 Td (${text}) Tj ET`;
    objs.set(4 + i * 2, `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`);
  }
  objs.set(font, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");
  let out = "%PDF-1.4\n";
  const offsets = new Map();
  for (const n of [...objs.keys()].sort((a, b) => a - b)) {
    offsets.set(n, out.length);
    out += `${n} 0 obj\n${objs.get(n)}\nendobj\n`;
  }
  const xref = out.length;
  out += `xref\n0 ${objs.size + 1}\n0000000000 65535 f \n`;
  for (const n of [...objs.keys()].sort((a, b) => a - b)) out += `${String(offsets.get(n)).padStart(10, "0")} 00000 n \n`;
  out += `trailer\n<< /Size ${objs.size + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  writeFileSync(path, out, "latin1");
}

function runDates(day) {
  const r = spawnSync(process.execPath, [DATES, "--today", day], { encoding: "utf8" });
  return [r.status, r.stdout ? JSON.parse(r.stdout) : null];
}

test("each weekday", () => {
  const expect = { "2024-11-25": "2024-11-30", "2024-11-29": "2024-11-30", "2024-11-30": "2024-11-30", "2024-12-01": "2024-11-30" };
  for (const [today, sat] of Object.entries(expect)) {
    const [code, out] = runDates(today);
    assert.deepEqual([code, out.saturday], [0, sat]);
    assert.equal(out.sunday, "2024-12-01");
  }
});

test("bad date", () => {
  assert.equal(runDates("tomorrow")[0], 2);
  assert.equal(runDates("2024-02-31")[0], 2);
});

let tmp;
before(() => { tmp = mkdtempSync(join(tmpdir(), "sheet-")); });
after(() => { rmSync(tmp, { recursive: true }); });

function pdf(name, opts) {
  const path = join(tmp, name);
  makePdf(path, opts);
  return path;
}

function check(path, env) {
  const r = spawnSync("bash", [SHEET, path], { encoding: "utf8", env });
  return [r.status, JSON.parse(r.stdout), r.stderr];
}

test("sheet ok", () => {
  const [code, out] = check(pdf("ok.pdf"));
  assert.deepEqual([code, out.pages], [0, 1]);
});

test("sheet too many pages", () => {
  assert.equal(check(pdf("three.pdf", { pages: 3 }))[0], 1);
});

test("sheet not letter", () => {
  const [code, out] = check(pdf("a4.pdf", { size: [595, 842] }));
  assert.equal(code, 1);
  assert.match(out.failures[0], /size/);
});

test("sheet url in text", () => {
  const [code, out] = check(pdf("url.pdf", { text: "see https://example.test/page" }));
  assert.equal(code, 1);
  assert.deepEqual(out.urls, ["https://example.test/page"]);
});

function whichTool(tool) {
  const r = spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" });
  return r.stdout.trim();
}

test("fallback without poppler", () => {
  const bindir = join(tmp, "bin");
  mkdirSync(bindir, { recursive: true });
  for (const tool of ["jq", "node", "awk", "grep", "tr", "cat", "env", "printf", "dirname"]) {
    const found = tool === "node" ? process.execPath : whichTool(tool);
    if (found && !existsSync(join(bindir, tool))) symlinkSync(found, join(bindir, tool));
  }
  const env = { PATH: bindir, HOME: tmp };
  const bash = whichTool("bash");
  let r = spawnSync(bash, [SHEET, pdf("fb.pdf")], { encoding: "utf8", env });
  const out = JSON.parse(r.stdout);
  assert.deepEqual([r.status, out.pages], [0, 1]);
  assert.ok(out.skipped.includes("urls"));
  assert.match(r.stderr, /warning/);
  r = spawnSync(bash, [SHEET, pdf("fb3.pdf", { pages: 3 })], { encoding: "utf8", env });
  assert.equal(r.status, 1);
});

test("sheet usage", () => {
  assert.equal(spawnSync("bash", [SHEET]).status, 2);
  assert.equal(spawnSync("bash", [SHEET, "/nonexistent.pdf"]).status, 2);
});
