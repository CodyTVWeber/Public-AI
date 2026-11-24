import os

from .analysis import Context, build_source
from .languages import is_generated_path
from .rules_comments import check_comments
from .rules_file import duplicate_findings, layer_findings, size_findings
from .rules_functions import check_functions
from .rules_lines import empty_catch_findings, magic_findings

CHECKS = (
    check_comments,
    empty_catch_findings,
    check_functions,
    magic_findings,
    size_findings,
    layer_findings,
    duplicate_findings,
)


def analyze_target(target, config):
    if is_generated_path(target.path):
        return []
    source = build_source(target.path, target.text)
    if source is None:
        return []
    ctx = Context(source, target.change, config.limits)
    findings = [item for check in CHECKS for item in check(ctx)]
    extension = os.path.splitext(target.path)[1].lstrip(".").lower()
    return [item for item in findings if not config.is_disabled(item.rule, extension)]


def analyze_all(targets, config):
    findings = []
    for target in targets:
        findings.extend(analyze_target(target, config))
    return sorted(findings, key=lambda item: (item.file, item.line, item.rule))
