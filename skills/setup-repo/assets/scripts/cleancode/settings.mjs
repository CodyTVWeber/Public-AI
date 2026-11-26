const SKIP_VARIABLES = ["CC_SKIP", "CLEAN_CODE_SKIP"];
const SKIP_VALUE = "1";
const DISABLE_VARIABLE = "CC_DISABLE";
const DEFAULTS = {
  funcWarn: 40, funcError: 80, paramsError: 4, nestWarn: 3, nestError: 4, fileWarn: 200, fileError: 400,
};
const VARIABLES = {
  funcWarn: "CC_FUNC_WARN", funcError: "CC_FUNC_ERROR", paramsError: "CC_PARAMS_ERROR",
  nestWarn: "CC_NEST_WARN", nestError: "CC_NEST_ERROR", fileWarn: "CC_FILE_WARN", fileError: "CC_FILE_ERROR",
};

function readInt(env, name, fallback) {
  const raw = (env[name] || "").trim();
  return /^\d+$/.test(raw) ? parseInt(raw, 10) : fallback;
}

function loadLimits(env) {
  const limits = {};
  for (const key of Object.keys(DEFAULTS)) limits[key] = readInt(env, VARIABLES[key], DEFAULTS[key]);
  return limits;
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

export function loadConfig(env) {
  const disabled = parseDisabled(env[DISABLE_VARIABLE] || "");
  const isDisabled = (rule, extension) => {
    if (!disabled.has(rule)) return false;
    const scope = disabled.get(rule);
    return scope === null || scope.has(extension);
  };
  return { limits: loadLimits(env), isDisabled };
}

export function skipReason(env) {
  return SKIP_VARIABLES.find((name) => (env[name] || "") === SKIP_VALUE) || null;
}
