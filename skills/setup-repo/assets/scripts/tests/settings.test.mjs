import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { spawnSync } from "node:child_process";
import {
  ConfigError, DEFAULT_FUNC_SIZE, FUNC_SIZE_PROFILES, loadConfig,
} from "../cleancode/settings.mjs";

const scratch = mkdtempSync(path.join(tmpdir(), "cc-func-size-"));

test("default profile is b 20/40", () => {
  assert.equal(DEFAULT_FUNC_SIZE, "b");
  assert.deepEqual(FUNC_SIZE_PROFILES.b, { funcWarn: 20, funcError: 40 });
  assert.deepEqual(FUNC_SIZE_PROFILES.a, { funcWarn: 40, funcError: 80 });
  assert.deepEqual(FUNC_SIZE_PROFILES.c, { funcWarn: 50, funcError: 100 });
});

test("env CC_FUNC_SIZE selects the pair", () => {
  const { limits } = loadConfig({ CC_FUNC_SIZE: "a" }, scratch);
  assert.equal(limits.funcWarn, 40);
  assert.equal(limits.funcError, 80);
});

test("CC_FUNC_WARN overrides the profile warn cap", () => {
  const { limits } = loadConfig({ CC_FUNC_SIZE: "b", CC_FUNC_WARN: "12" }, scratch);
  assert.equal(limits.funcWarn, 12);
  assert.equal(limits.funcError, 40);
});

test("unknown CC_FUNC_SIZE throws ConfigError", () => {
  assert.throws(() => loadConfig({ CC_FUNC_SIZE: "z" }, scratch), ConfigError);
});

test("repo .func-size is read when env is unset", () => {
  const repo = mkdtempSync(path.join(scratch, "repo-"));
  spawnSync("git", ["init", "-q"], { cwd: repo });
  writeFileSync(path.join(repo, ".func-size"), "size: c\n");
  const { limits } = loadConfig({}, repo);
  assert.equal(limits.funcWarn, 50);
  assert.equal(limits.funcError, 100);
});
