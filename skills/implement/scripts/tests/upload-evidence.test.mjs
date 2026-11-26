import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createServer } from "node:http";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), "..", "upload-evidence.mjs");
const seen = [];
let server;
let host;
let tmp;

before(async () => {
  server = createServer((req, res) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const body = Buffer.concat(chunks).toString("latin1");
      seen.push([req.url, req.headers["private-token"], body]);
      if (body.includes("fail.png")) {
        res.writeHead(500).end();
        return;
      }
      res.writeHead(201, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ markdown: "![x](/uploads/x)" }));
    });
  });
  await new Promise((resolve) => server.listen(0, "localhost", resolve));
  host = `http://localhost:${server.address().port}`;
  tmp = mkdtempSync(join(tmpdir(), "upload-"));
});

after(() => {
  server.close();
  rmSync(tmp, { recursive: true });
});

function run(args, env = {}) {
  const full = { ...process.env, GL_TOKEN: "stub", ...env };
  for (const k of Object.keys(full)) if (full[k] === undefined) delete full[k];
  return new Promise((resolve) => {
    execFile(process.execPath, [SCRIPT, ...args], { env: full }, (err, stdout, stderr) => {
      resolve({ code: err ? err.code : 0, stdout, stderr });
    });
  });
}

function make(name, data = "x".repeat(64)) {
  const path = join(tmp, name);
  writeFileSync(path, data);
  return path;
}

test("mime by extension", async () => {
  const cases = [["a.png", "image/png"], ["b.mp4", "video/mp4"], ["c.webm", "video/webm"], ["d.jpg", "image/jpeg"], ["e.gif", "image/gif"], ["f.webp", "image/webp"]];
  for (const [name, mime] of cases) {
    seen.length = 0;
    const r = await run(["42", make(name), "--host", host]);
    assert.equal(r.code, 0, r.stderr);
    assert.ok(seen[0][2].includes(`Content-Type: ${mime}`));
    assert.equal(seen[0][0], "/api/v4/projects/42/uploads");
    assert.equal(seen[0][1], "stub");
    assert.deepEqual(JSON.parse(r.stdout), { [name]: "![x](/uploads/x)" });
  }
});

test("host from env", async () => {
  const r = await run(["1", make("env.png")], { GL_HOST: host });
  assert.equal(r.code, 0, r.stderr);
});

test("dry run makes no request", async () => {
  seen.length = 0;
  const r = await run(["1", make("dry.mp4"), "--dry-run"]);
  assert.equal(r.code, 0, r.stderr);
  const out = JSON.parse(r.stdout);
  assert.equal(out.dry_run, true);
  assert.equal(out.files[0].mime, "video/mp4");
  assert.deepEqual(seen, []);
});

test("missing file", async () => {
  const r = await run(["1", join(tmp, "nope.png"), "--host", host]);
  assert.equal(r.code, 2);
  assert.ok("error" in JSON.parse(r.stdout));
});

test("empty file", async () => {
  assert.equal((await run(["1", make("empty.png", ""), "--host", host])).code, 2);
});

test("bad extension", async () => {
  assert.equal((await run(["1", make("note.txt"), "--host", host])).code, 2);
});

test("too large", async () => {
  assert.equal((await run(["1", make("big.png", "x".repeat(100)), "--host", host, "--max-bytes", "10"])).code, 2);
});

test("no token", async () => {
  const r = await run(["1", make("t.png"), "--host", host], { GL_TOKEN: undefined });
  assert.equal(r.code, 3);
});

test("upload failure", async () => {
  const r = await run(["1", make("fail.png"), "--host", host]);
  assert.equal(r.code, 4);
  assert.match(JSON.parse(r.stdout).error, /HTTP 500/);
});

test("usage", async () => {
  assert.equal((await run([])).code, 2);
});
