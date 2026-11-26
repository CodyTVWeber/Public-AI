import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const LINT = join(HERE, "..", "draft-lint.mjs");
const PATH_SH = join(HERE, "..", "draft-path.sh");
const CONFIG = { greeting: "Hi", closings: ["Thanks,"], signature: "Sender Name", phone: "x4455" };

const GOOD = [
  "**To:** Recipient",
  "**Subject:** License renewal",
  "",
  "Hi Recipient,",
  "",
  "Quick follow-up on the license renewal.",
  "",
  "1. **Seats**",
  "   - Please put the seat count in writing",
  "     - Annual plan only",
  "",
  "2. **Schedule**",
  "   - Renew the week of the 14th",
  "",
  "Thanks,",
  "Sender Name",
  "x4455",
  "",
].join("\n");

let tmp;
let config;

before(() => {
  tmp = mkdtempSync(join(tmpdir(), "lint-"));
  config = join(tmp, "cfg.json");
  writeFileSync(config, JSON.stringify(CONFIG));
});
after(() => rmSync(tmp, { recursive: true }));

function write(text, name = "draft.md") {
  const path = join(tmp, name);
  writeFileSync(path, text);
  return path;
}

function runLint(text, ...args) {
  return spawnSync(process.execPath, [LINT, write(text), ...args], { encoding: "utf8" });
}

function lint(text, ...args) {
  const r = runLint(text, "--config", config, ...args);
  return [r.status, new Set(JSON.parse(r.stdout).map((v) => v.rule))];
}

test("clean", () => {
  assert.deepEqual(lint(GOOD), [0, new Set()]);
});

test("banned discussion variants", () => {
  for (const phrase of ["As briefly discussed", "As discussed in our earlier correspondence", "As discussed in our correspondence"]) {
    assert.ok(lint(GOOD.replace("Quick", `${phrase}, quick`))[1].has("banned_phrase"));
  }
});

test("banned phrase and tz", () => {
  const [code, rules] = lint(GOOD.replace("Quick follow-up", "Thanks so much. Call at 3pm EST. Quick follow-up"));
  assert.equal(code, 1);
  assert.ok(rules.has("banned_phrase") && rules.has("tz_label"));
});

test("tz allowed when elsewhere", () => {
  const text = GOOD.replace("the 14th", "the 14th at 3pm EST");
  assert.ok(lint(text)[1].has("tz_label"));
  assert.ok(!lint(text, "--recipient-elsewhere")[1].has("tz_label"));
});

test("greeting from config", () => {
  assert.ok(lint(GOOD.replace("Hi Recipient,", "Recipient,"))[1].has("greeting_mismatch"));
  assert.ok(lint(GOOD.replace("Hi Recipient,", "Hello Recipient,"))[1].has("greeting_mismatch"));
});

test("opening length", () => {
  const text = GOOD.replace("Quick follow-up on the license renewal.", "One. Two. Three.");
  assert.ok(lint(text)[1].has("opening_over_2_sentences"));
});

test("emoji", () => {
  assert.ok(lint(GOOD.replace("Seats", "Seats \u{1F600}"))[1].has("emoji"));
});

test("fenced lines ignored", () => {
  const text = GOOD.replace("\nThanks,", "\n```\nhope you're well\n```\nThanks,");
  assert.deepEqual(lint(text), [0, new Set()]);
});

test("headers", () => {
  assert.ok(lint(GOOD.replace("**Subject:** License renewal\n", ""))[1].has("header_missing:subject"));
});

test("closing signature phone", () => {
  assert.ok(lint(GOOD.replace("Thanks,", "Regards,"))[1].has("closing_missing"));
  assert.ok(lint(GOOD.replace("x4455", ""))[1].has("phone_missing"));
  assert.ok(lint(GOOD.replace("Sender Name", "Someone"))[1].has("signature_missing"));
});

test("skip", () => {
  assert.equal(lint(GOOD.replace("x4455", ""), "--skip", "phone")[0], 0);
});

test("closing differs per config", () => {
  const path = join(tmp, "other.json");
  writeFileSync(path, JSON.stringify({ closings: ["Regards,"] }));
  assert.equal(runLint(GOOD.replace("Thanks,", "Regards,"), "--config", path).status, 0);
  assert.match(runLint(GOOD, "--config", path).stdout, /closing_missing/);
});

test("output profile ignores email shape", () => {
  let r = runLint("Done. Ship it.\n\n1. **Next**\n   - go\n", "--profile", "output");
  assert.deepEqual([r.status, r.stdout.trim()], [0, "[]"]);
  r = runLint("Please don't hesitate.\n", "--profile", "output");
  assert.deepEqual(new Set(JSON.parse(r.stdout).map((v) => v.rule)), new Set(["banned_phrase"]));
});

test("output profile opening length", () => {
  const r = runLint("One. Two. Three.\n\n1. **Next**\n", "--profile", "output");
  assert.match(r.stdout, /opening_over_2_sentences/);
});

test("missing config skips personal checks", () => {
  const text = GOOD.replace("Thanks,\nSender Name\nx4455\n", "");
  const r = runLint(text, "--config", join(tmp, "none.json"));
  assert.equal(r.status, 0);
  assert.match(r.stderr, /skipped/);
});

test("env config", () => {
  const env = { ...process.env, AI_SKILLS_EMAIL_CONFIG: config };
  const r = spawnSync(process.execPath, [LINT, write(GOOD.replace("x4455", ""))], { encoding: "utf8", env });
  assert.match(r.stdout, /phone_missing/);
});

test("unreadable file", () => {
  assert.equal(spawnSync(process.execPath, [LINT, join(tmp, "nope.md")]).status, 2);
});

function runSh(...args) {
  return spawnSync("bash", [PATH_SH, ...args], { encoding: "utf8" });
}

test("draft path", () => {
  const d = mkdtempSync(join(tmpdir(), "dp-"));
  try {
    const path = JSON.parse(runSh("--dir", d, "license renewal").stdout).path;
    assert.equal(path, `${d}/draft-license-renewal.md`);
    writeFileSync(path, "");
    assert.equal(JSON.parse(runSh("--dir", d, "license renewal").stdout).path, `${d}/draft-license-renewal-2.md`);
  } finally {
    rmSync(d, { recursive: true });
  }
});

test("draft path slug", () => {
  const d = mkdtempSync(join(tmpdir(), "dp-"));
  try {
    assert.equal(JSON.parse(runSh("--dir", d, "Q3: Seats & Support!").stdout).path, `${d}/draft-q3-seats-support.md`);
  } finally {
    rmSync(d, { recursive: true });
  }
});

test("draft path usage", () => {
  assert.equal(runSh().status, 2);
  assert.equal(runSh("--bogus", "x").status, 2);
  assert.equal(runSh("!!!").status, 2);
  assert.equal(runSh("--help").status, 0);
});
