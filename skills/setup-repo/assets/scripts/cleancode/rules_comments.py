import re
from dataclasses import dataclass

from .catalog import make_finding
from .model import ERROR, WARN

TODO = re.compile(r"\b(?:TODO|FIXME|XXX)\b")
BANNER = re.compile(r"^(?:STATUS:|[=\-#*~_/]{4,})")
ALWAYS_ALLOWED = re.compile(
    r"^(?:SPDX-License-Identifier:|Copyright\b|go:(?:build|generate|embed|linkname)\b"
    r"|\+build\b|Code generated\b|-\*-|(?:en)?coding[:=]|frozen_string_literal:"
    r"|shellcheck\s+(?:shell|source|source-path)=|/\s*<reference\b|eslint-enable\b)"
)
DIRECTIVE = re.compile(
    r"^(?:eslint-disable\S*|@ts-[\w-]+|noqa\b|type:\s*ignore|pylint:|pragma:|istanbul\b"
    r"|prettier-ignore|nolint|shellcheck\s+disable|NOSONAR|detekt:|rubocop:|swiftlint:|fmt:)"
)
REASON = re.compile(r"\s--\s+\S*\w")
SHEBANG_LINE = 1
PREVIEW_LENGTH = 60


@dataclass
class CommentBlock:
    lines: list
    texts: list
    attached: bool = False


def python_docstring_blocks(src):
    blocks = []
    for start, end, attached in src.docstrings:
        first = src.raw[start].strip().strip("\"'").strip()
        blocks.append(CommentBlock(list(range(start, end + 1)), [first], attached))
    return blocks


def is_shebang(comment):
    return comment.line == SHEBANG_LINE and comment.text.startswith("!")


def group_comments(comments):
    blocks = []
    last = None
    for comment in sorted(comments, key=lambda item: (item.line, item.col)):
        if is_shebang(comment):
            continue
        joins = last and comment.standalone and last.standalone and comment.line <= last.line + 1
        if joins:
            blocks[-1].lines.append(comment.line)
            blocks[-1].texts.append(comment.text)
        else:
            blocks.append(CommentBlock([comment.line], [comment.text]))
        last = comment
    return blocks


def text_allowed(text, line):
    if not text:
        return True
    if line == SHEBANG_LINE and text.startswith("!"):
        return True
    if ALWAYS_ALLOWED.match(text):
        return True
    return bool(DIRECTIVE.match(text) and REASON.search(text))


def classify(block):
    joined = "\n".join(block.texts)
    if any(BANNER.match(text) for text in block.texts):
        return "banner"
    if TODO.search(joined):
        return "todo-marker"
    pairs = zip(block.texts, block.lines)
    if all(text_allowed(text, line) for text, line in pairs):
        return None
    return "added-comment"


def describe(rule, block):
    preview = next((text for text in block.texts if text), "")[:PREVIEW_LENGTH]
    return {
        "banner": "banner or STATUS line: " + preview,
        "todo-marker": "TODO marker: " + preview,
        "added-comment": "added comment: " + preview,
        "docstring": "docstring: " + preview,
    }[rule]


def verdict_of(rule, block):
    if rule == "added-comment" and block.attached:
        return "docstring", WARN
    return rule, ERROR


def check_comments(ctx):
    blocks = group_comments(ctx.src.lexed.comments) + python_docstring_blocks(ctx.src)
    findings = []
    for block in blocks:
        touched = [line for line in block.lines if ctx.change.has(line)]
        rule = classify(block) if touched else None
        if rule:
            verdict = verdict_of(rule, block)
            site = (ctx.src.path, touched[0])
            findings.append(make_finding(site, verdict, describe(verdict[0], block)))
    return findings
