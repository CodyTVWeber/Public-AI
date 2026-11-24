from dataclasses import dataclass

SKIP_VARIABLES = ("CC_SKIP", "CLEAN_CODE_SKIP")
SKIP_VALUE = "1"
DISABLE_VARIABLE = "CC_DISABLE"
DEFAULT_FUNC_WARN = 40
DEFAULT_FUNC_ERROR = 80
DEFAULT_PARAMS_ERROR = 4
DEFAULT_NEST_WARN = 3
DEFAULT_NEST_ERROR = 4
DEFAULT_FILE_WARN = 200
DEFAULT_FILE_ERROR = 400


@dataclass(frozen=True)
class Limits:
    func_warn: int = DEFAULT_FUNC_WARN
    func_error: int = DEFAULT_FUNC_ERROR
    params_error: int = DEFAULT_PARAMS_ERROR
    nest_warn: int = DEFAULT_NEST_WARN
    nest_error: int = DEFAULT_NEST_ERROR
    file_warn: int = DEFAULT_FILE_WARN
    file_error: int = DEFAULT_FILE_ERROR


@dataclass(frozen=True)
class Config:
    limits: Limits
    disabled: dict

    def is_disabled(self, rule, extension):
        if rule not in self.disabled:
            return False
        scope = self.disabled[rule]
        return scope is None or extension in scope


def read_int(env, name, default):
    raw = env.get(name, "").strip()
    return int(raw) if raw.isdigit() else default


def load_limits(env):
    defaults = Limits()
    return Limits(
        func_warn=read_int(env, "CC_FUNC_WARN", defaults.func_warn),
        func_error=read_int(env, "CC_FUNC_ERROR", defaults.func_error),
        params_error=read_int(env, "CC_PARAMS_ERROR", defaults.params_error),
        nest_warn=read_int(env, "CC_NEST_WARN", defaults.nest_warn),
        nest_error=read_int(env, "CC_NEST_ERROR", defaults.nest_error),
        file_warn=read_int(env, "CC_FILE_WARN", defaults.file_warn),
        file_error=read_int(env, "CC_FILE_ERROR", defaults.file_error),
    )


def parse_disabled(text):
    disabled = {}
    for token in text.replace(" ", "").split(","):
        rule, _, scope = token.partition("@")
        if rule:
            disabled[rule] = frozenset(scope.split("+")) if scope else None
    return disabled


def load_config(env):
    return Config(load_limits(env), parse_disabled(env.get(DISABLE_VARIABLE, "")))


def skip_reason(env):
    for name in SKIP_VARIABLES:
        if env.get(name, "") == SKIP_VALUE:
            return name
    return None
