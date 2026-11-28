import fs from "node:fs";
import path from "node:path";
import { git } from "./gitdiff.mjs";

export class ConfigError extends Error {}

const WARN_A = 40;
const ERROR_A = 80;
const WARN_B = 20;
const ERROR_B = 40;
const WARN_C = 50;
const ERROR_C = 100;
const PARAMS_ERROR = 4;
const NEST_WARN = 3;
const NEST_ERROR = 4;
const FILE_WARN = 200;
const FILE_ERROR = 400;

export const FUNC_SIZE_PROFILES = {
  a: { funcWarn: WARN_A, funcError: ERROR_A },
  b: { funcWarn: WARN_B, funcError: ERROR_B },
  c: { funcWarn: WARN_C, funcError: ERROR_C },
};
export const DEFAULT_FUNC_SIZE = "b";

const SKIP_VARIABLES = ["CC_SKIP", "CLEAN_CODE_SKIP"];
const SKIP_VALUE = "1";
const DISABLE_VARIABLE = "CC_DISABLE";
const SIZE_FILE = ".func-size";
const SIZE_LINE = /^size:\s*(\S+)\s*$/i;
const DEFAULTS = {
  paramsError: PARAMS_ERROR, nestWarn: NEST_WARN, nestError: NEST_ERROR,
  fileWarn: FILE_WARN, fileError: FILE_ERROR,
};
const VARIABLES = {
  funcWarn: "CC_FUNC_WARN", funcError: "CC_FUNC_ERROR", paramsError: "CC_PARAMS_ERROR",
  nestWarn: "CC_NEST_WARN", nestError: "CC_NEST_ERROR", fileWarn: "CC_FILE_WARN", fileError: "CC_FILE_ERROR",
};

export function loadConfig(env, cwd = process.cwd()) {
  const disabled = parseDisabled(env[DISABLE_VARIABLE] || "");
  return { limits: loadLimits(env, cwd), isDisabled: ruleDisabled(disabled) };
}

export function skipReason(env) {
  return SKIP_VARIABLES.find((name) => (env[name] || "") === SKIP_VALUE) || null;
}

function ruleDisabled(disabled) {
  return (rule, extension) => {
    if (!disabled.has(rule)) return false;
    const scope = disabled.get(rule);
    return scope === null || scope.has(extension);
  };
}

function loadLimits(env, cwd) {
  const fallback = { ...DEFAULTS, ...FUNC_SIZE_PROFILES[chosenSize(env, cwd)] };
  const limits = {};
  for (const key of Object.keys(fallback)) limits[key] = envInt(env, VARIABLES[key]) ?? fallback[key];
  return limits;
}

function chosenSize(env, cwd) {
  return namedProfile(env.CC_FUNC_SIZE || "") || fileProfile(gitRoot(cwd)) || DEFAULT_FUNC_SIZE;
}

function fileProfile(root) {
  const text = root ? readSizeFile(root) : null;
  if (text === null) return null;
  for (const line of text.split("\n")) {
    const found = lineProfile(line);
    if (found) return found;
  }
  return null;
}

function readSizeFile(root) {
  try {
    return fs.readFileSync(path.join(root, SIZE_FILE), "utf8");
  } catch {
    return null;
  }
}

function lineProfile(line) {
  const match = SIZE_LINE.exec(line.trim());
  return match ? namedProfile(match[1]) : null;
}

function namedProfile(value) {
  const key = value.trim().toLowerCase();
  if (!key) return null;
  if (key in FUNC_SIZE_PROFILES) return key;
  throw new ConfigError(`unknown function-size profile '${value.trim()}' (want a, b, or c)`);
}

function gitRoot(cwd) {
  const [code, out] = git(cwd, ["rev-parse", "--show-toplevel"]);
  return code === 0 ? out.trim() : null;
}

function parseDisabled(text) {
  const disabled = new Map();
  for (const token of text.replaceAll(" ", "").split(",")) {
    const at = token.indexOf("@");
    const rule = at < 0 ? token : token.slice(0, at);
    const scope = at < 0 ? "" : token.slice(at + 1);
    if (rule) disabled.set(rule, scope ? new Set(scope.split("+")) : null);
  }
  return disabled;
}

function envInt(env, name) {
  const raw = (env[name] || "").trim();
  return /^\d+$/.test(raw) ? Number(raw) : null;
}
