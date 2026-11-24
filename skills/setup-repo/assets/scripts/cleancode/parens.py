from dataclasses import dataclass

MAX_HEADER_LINES = 14
OPENERS = "([{"
CLOSERS = ")]}"
CONTINUATION = "\\"


@dataclass
class Statement:
    start: int
    end: int
    indent: int
    text: str


def balanced_inner(text, open_index):
    depth = 0
    for index in range(open_index, len(text)):
        depth += text[index] == "("
        depth -= text[index] == ")"
        if depth == 0:
            return text[open_index + 1:index], index
    return None


def match_paren(masked, position):
    line, col = position
    last = min(len(masked) - 1, line + MAX_HEADER_LINES)
    chunk = "\n".join(masked[line:last + 1])
    found = balanced_inner(chunk, col)
    if found is None:
        return None
    inner, close = found
    row = chunk.count("\n", 0, close)
    column = close - (chunk.rfind("\n", 0, close) + 1)
    return inner.replace("\n", " "), line + row, column


def net_brackets(line):
    opened = sum(line.count(char) for char in OPENERS)
    closed = sum(line.count(char) for char in CLOSERS)
    return opened - closed


def indent_of(line):
    return len(line) - len(line.lstrip())


def statements(masked, continuation):
    result = []
    depth = 0
    current = None
    for number in range(1, len(masked)):
        line = masked[number]
        if not line.strip():
            continue
        if depth > 0 or number in continuation or current_continues(current):
            current.end = number
            current.text += " " + line.strip()
        else:
            current = Statement(number, number, indent_of(line), line.strip())
            result.append(current)
        depth = max(0, depth + net_brackets(line))
    return result


def current_continues(current):
    return current is not None and current.text.endswith(CONTINUATION)
