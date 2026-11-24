from .catalog import make_finding
from .model import ERROR, WARN
from .params import is_bool_flag
from .rules_mutation import mutation_findings
from .rules_try import try_findings


def grade(value, thresholds):
    error_at, warn_at = thresholds
    if value >= error_at:
        return ERROR
    return WARN if value >= warn_at else None


def length_findings(ctx, function):
    if ctx.src.is_test:
        return []
    limits = ctx.limits
    severity = grade(function.logic, (limits.func_error + 1, limits.func_warn + 1))
    if severity is None:
        return []
    message = "%s() is %d lines of logic" % (function.name, function.logic)
    site = (ctx.src.path, function.start)
    return [make_finding(site, ("function-length", severity), message)]


def param_findings(ctx, function):
    count = len(function.params)
    severity = grade(count, (ctx.limits.params_error, ctx.limits.params_error - 1))
    if severity is None:
        return []
    message = "%s() takes %d params" % (function.name, count)
    site = (ctx.src.path, function.start)
    return [make_finding(site, ("param-count", severity), message)]


def nesting_findings(ctx, function):
    severity = grade(function.max_depth, (ctx.limits.nest_error, ctx.limits.nest_warn))
    if severity is None:
        return []
    message = "%s() nests control flow %d deep" % (function.name, function.max_depth)
    site = (ctx.src.path, function.depth_line)
    return [make_finding(site, ("nesting-depth", severity), message)]


def flag_findings(ctx, function):
    flags = [param.name for param in function.params if is_bool_flag(param)]
    if not flags:
        return []
    message = "%s() takes boolean flag %s" % (function.name, ", ".join(flags))
    site = (ctx.src.path, function.start)
    return [make_finding(site, ("bool-flag-param", WARN), message)]


CHECKS = (
    length_findings,
    param_findings,
    nesting_findings,
    flag_findings,
    mutation_findings,
    try_findings,
)


def check_functions(ctx):
    findings = []
    for function in ctx.src.structure.functions:
        if not ctx.change.touches(function.start, function.end):
            continue
        for check in CHECKS:
            findings.extend(check(ctx, function))
    return findings
