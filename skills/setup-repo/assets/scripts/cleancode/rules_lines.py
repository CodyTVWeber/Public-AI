import re

from .catalog import make_finding
from .model import ERROR, WARN

NUMBER = re.compile(
    r"(?<![\w.$#@])-?(?:0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)[uUlLfFdD]?(?![\w])"
)
INDEX = re.compile(r"\[[\s\d:+\-]*\]|\.group\(\s*\d+\s*\)")
EXIT_CALL = re.compile(r"\bexit\w*\s*\(?\s*-?\d")
CONSTANT_LINE = re.compile(
    r"^\s*(?:(?:export|public|private|protected|internal|static|final|const|readonly|val|var|let|pub|default)\s+)*"
    r"[A-Z][A-Z0-9_]+\b"
)
CONSTANT_KEYWORD = re.compile(
    r"\b(?:const|static\s+final|final\s+static|readonly|enum)\b"
)
ALLOWED_VALUES = frozenset({-1.0, 0.0, 1.0, 2.0})
SKIPPED_LANGUAGES = frozenset({"shell"})
ANNOTATION_START = "@"
SUFFIX_LETTERS = "uUlLfFdD"
MAGIC = ("magic-number", WARN)
EMPTY_CATCH = ("empty-catch", ERROR)


def parse_number(text):
    for parser in (lambda value: int(value, 0), float):
        try:
            return float(parser(text))
        except ValueError:
            continue
    return None


def literal_value(token):
    text = token.replace("_", "")
    if not text.lower().lstrip("-").startswith("0x"):
        text = text.rstrip(SUFFIX_LETTERS)
    return parse_number(text)


def header_lines(function_list):
    lines = set()
    for function in function_list:
        lines.update(range(function.start, function.header_end + 1))
    return lines


def exempt_line(text):
    stripped = text.strip()
    if not stripped or stripped.startswith(ANNOTATION_START):
        return True
    if CONSTANT_LINE.match(text) or CONSTANT_KEYWORD.search(text):
        return True
    return bool(EXIT_CALL.search(text))


def first_magic(text):
    for found in NUMBER.finditer(INDEX.sub("", text)):
        value = literal_value(found.group(0))
        if value is not None and value not in ALLOWED_VALUES:
            return found.group(0)
    return None


def magic_findings(ctx):
    src = ctx.src
    if src.is_test or src.lang in SKIPPED_LANGUAGES:
        return []
    skipped = header_lines(src.structure.functions)
    findings = []
    for number in range(1, len(src.masked)):
        text = src.masked[number]
        if number in skipped or not ctx.change.has(number) or exempt_line(text):
            continue
        token = first_magic(text)
        if token:
            message = "magic number " + token
            findings.append(make_finding((src.path, number), MAGIC, message))
    return findings


def empty_catch_findings(ctx):
    findings = []
    for block in ctx.src.structure.blocks:
        if block.kind == "catch" and block.empty and ctx.change.touches(block.start, block.end):
            site = (ctx.src.path, block.start)
            findings.append(make_finding(site, EMPTY_CATCH, "empty catch/except handler"))
    return findings
