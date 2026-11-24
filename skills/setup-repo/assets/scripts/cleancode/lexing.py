from dataclasses import dataclass, field

from .lexer import Scanner


@dataclass
class Comment:
    line: int
    col: int
    text: str
    standalone: bool = True


@dataclass
class Lexed:
    raw: list
    masked: list
    comments: list = field(default_factory=list)
    strings: list = field(default_factory=list)
    triples: list = field(default_factory=list)


def split_lines(text):
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return lines


def lex(raw, spec):
    scanner = Scanner(spec, Comment)
    masked = [""]
    for number, line in enumerate(raw[1:], 1):
        masked.append(scanner.feed(line, number))
    for comment in scanner.comments:
        comment.standalone = not masked[comment.line][: comment.col].strip()
    return Lexed(raw, masked, scanner.comments, scanner.strings, scanner.triples)
