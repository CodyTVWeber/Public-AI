import re
from dataclasses import dataclass

from .languages import is_test_path, spec_for
from .lexing import lex, split_lines
from .structure import build_structure

DOC_QUOTES = ('"""', "'''")
BLOCK_OPENER = re.compile(r"^(?:async\s+)?(?:if|elif|else|for|while|try|except|finally|with|match|case)\b")


@dataclass
class Source:
    path: str
    spec: object
    raw: list
    lexed: object
    structure: object
    docstrings: list
    is_test: bool

    @property
    def masked(self):
        return self.lexed.masked

    @property
    def lang(self):
        return self.spec.name

    @property
    def line_count(self):
        return len(self.raw) - 1


@dataclass
class Context:
    src: Source
    change: object
    limits: object


def previous_code_line(masked, number):
    for index in range(number - 1, 0, -1):
        if masked[index].strip():
            return masked[index].strip()
    return ""


def docstring_ranges(lexed):
    masked = lexed.masked
    found = []
    for start, col, end in lexed.triples:
        if masked[start][:col].strip():
            continue
        if not masked[end].rstrip().endswith(DOC_QUOTES):
            continue
        previous = previous_code_line(masked, start)
        if previous == "" or previous.endswith(":"):
            found.append((start, end, not BLOCK_OPENER.match(previous)))
    return found


def without_ranges(masked, ranges):
    hidden = {number for start, end, _ in ranges for number in range(start, end + 1)}
    return [("" if number in hidden else line) for number, line in enumerate(masked)]


def build_source(path, text):
    spec = spec_for(path)
    if spec is None:
        return None
    raw = [""] + split_lines(text)
    lexed = lex(raw, spec)
    docstrings = docstring_ranges(lexed) if spec.family == "python" else []
    lexed.masked = without_ranges(lexed.masked, docstrings)
    structure = build_structure(spec, lexed)
    return Source(path, spec, raw, lexed, structure, docstrings, is_test_path(path))
