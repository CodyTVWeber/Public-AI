from collections import defaultdict

from .catalog import make_finding
from .languages import layer_directory
from .model import ERROR, WARN

MIN_STRING_LENGTH = 6
MIN_REPEATS = 3
DUPLICATE = ("duplicate-string", WARN)
IMPORT_MARKERS = ("import ", "from ", "require(", "#include", "use ", "source ", ". ")


def size_findings(ctx):
    src = ctx.src
    if src.is_test or not ctx.change.grows:
        return []
    limits = ctx.limits
    total = src.line_count
    if total >= limits.file_error:
        severity = ERROR
    elif total > limits.file_warn:
        severity = WARN
    else:
        return []
    message = "%d lines and this change grows it" % total
    return [make_finding((src.path, 1), ("file-size", severity), message)]


def layer_findings(ctx):
    folder = layer_directory(ctx.src.path)
    if folder is None or not ctx.change.is_new or ctx.src.is_test:
        return []
    message = "new file under layer folder '%s'" % folder
    return [make_finding((ctx.src.path, 1), ("layer-folder", WARN), message)]


def countable(src, entry):
    number, text = entry
    if len(text) < MIN_STRING_LENGTH or not any(char.isalpha() for char in text):
        return False
    if src.lang == "shell" and "$" in text:
        return False
    return not src.raw[number].lstrip().startswith(IMPORT_MARKERS)


def duplicate_findings(ctx):
    src = ctx.src
    if src.is_test:
        return []
    seen = defaultdict(list)
    for entry in src.lexed.strings:
        if countable(src, entry):
            seen[entry[1]].append(entry[0])
    findings = []
    for text, lines in seen.items():
        touched = [line for line in lines if ctx.change.has(line)]
        if len(lines) >= MIN_REPEATS and touched:
            message = "string %r repeats %d times" % (text[:40], len(lines))
            findings.append(make_finding((src.path, touched[0]), DUPLICATE, message))
    return findings
