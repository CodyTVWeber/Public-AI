import re

from .catalog import make_finding
from .model import ERROR, WARN

LANGUAGES = frozenset({"js", "python", "kotlin", "java", "cs", "scala"})
MUTATOR_PREFIX = re.compile(
    r"^_*(?:set|fill|populate|write|apply|mutate|update|init|register|configure|merge"
    r"|assign|append|push|add|reset|clear|constructor)",
    re.IGNORECASE,
)
OUT_MARKERS = ("ref ", "out ", "inout ", "&mut ")
IDIOM_NAMES = frozenset({"res", "resp", "response", "req", "request", "ctx", "event", "evt", "self", "this"})
REF_NAME = re.compile(r"^(?:ref|\w+Ref)$")
RULE = "param-mutation"


def mutation_patterns(name):
    start = r"(?<![\w.$])" + re.escape(name)
    target = start + r"(?:\.\w+|\[[^\]]*\])+\s*(?:[-+*/|&^%]|<<|>>|\*\*|//|\?\?)?=(?![=>])"
    compound = start + r"\s*(?:\+=|-=|\*=|/=|\|=|&=)"
    return (re.compile(target), re.compile(compound))


def first_hit(body, patterns):
    for number, text in body:
        if any(pattern.search(text) for pattern in patterns):
            return number, text
    return None


def is_idiom(name, text):
    if name in IDIOM_NAMES:
        return True
    return bool(REF_NAME.match(name) and re.search(re.escape(name) + r"\.current\b", text))


def verdict_for(name, text):
    return (RULE, WARN if is_idiom(name, text) else ERROR)


def mutation_findings(ctx, function):
    if ctx.src.lang not in LANGUAGES or MUTATOR_PREFIX.match(function.name):
        return []
    masked = ctx.src.masked
    body = [(n, masked[n]) for n in range(function.header_end + 1, function.end + 1)]
    findings = []
    for param in function.params:
        if not param.name or param.raw.startswith(OUT_MARKERS):
            continue
        hit = first_hit(body, mutation_patterns(param.name))
        if hit is not None:
            message = "%s() mutates parameter %s" % (function.name, param.name)
            site = (ctx.src.path, hit[0])
            findings.append(make_finding(site, verdict_for(param.name, hit[1]), message))
    return findings
