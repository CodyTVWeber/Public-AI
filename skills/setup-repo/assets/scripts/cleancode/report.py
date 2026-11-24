import json

from .model import ERROR, WARN


def counts(findings):
    errors = sum(1 for item in findings if item.severity == ERROR)
    return errors, len(findings) - errors


def summary(findings, files):
    errors, warnings = counts(findings)
    return {"errors": errors, "warnings": warnings, "files": files, "skipped": False}


def to_json(findings, files):
    payload = {
        "findings": [item.to_dict() for item in findings],
        "summary": summary(findings, files),
    }
    return json.dumps(payload, separators=(",", ":"))


def skipped_json():
    payload = {"findings": [], "summary": {"errors": 0, "warnings": 0, "files": 0, "skipped": True}}
    return json.dumps(payload, separators=(",", ":"))


def label(severity):
    return "ERROR" if severity == ERROR else "WARN"


def render_human(findings):
    lines = []
    for item in findings:
        lines.append("%s:%d: %s [%s] %s" % (item.file, item.line, label(item.severity), item.rule, item.message))
        lines.append("    fix: " + item.fix_hint)
    return "\n".join(lines)


def headline(findings):
    errors, warnings = counts(findings)
    return "clean-code: %d error(s), %d warning(s) on lines you touched" % (errors, warnings)


def exit_code(findings):
    return 1 if any(item.severity == ERROR for item in findings) else 0


def only(findings, severity):
    return [item for item in findings if item.severity == severity]


def warnings_of(findings):
    return only(findings, WARN)
