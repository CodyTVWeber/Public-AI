from .catalog import make_finding
from .model import WARN

MIN_FUNCTION_LOGIC = 10
MIN_TRY_LOGIC = 5
FOLLOWERS = frozenset({"catch", "finally"})
VERDICT = ("inline-try-catch", WARN)


def try_groups(blocks, function):
    own = sorted((b for b in blocks if b.owner is function), key=lambda b: b.start)
    groups = []
    for block in own:
        if block.kind == "try":
            groups.append([block])
        elif block.kind in FOLLOWERS and groups and block.start <= groups[-1][-1].end + 1:
            groups[-1].append(block)
    return groups


def logic_between(masked, span):
    return sum(1 for number in range(span[0], span[1] + 1) if masked[number].strip())


def try_findings(ctx, function):
    if function.logic <= MIN_FUNCTION_LOGIC:
        return []
    findings = []
    for group in try_groups(ctx.src.structure.blocks, function):
        span = (group[0].start, group[-1].end)
        size = logic_between(ctx.src.masked, span)
        if size < MIN_TRY_LOGIC or not ctx.change.touches(*span):
            continue
        message = "%s() hosts an inline try/catch of %d lines" % (function.name, size)
        findings.append(make_finding((ctx.src.path, span[0]), VERDICT, message))
    return findings
