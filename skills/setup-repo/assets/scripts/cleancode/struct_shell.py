import re
from dataclasses import dataclass

from .model import Function, Param, Structure

FUNCTION_A = re.compile(r"^(\s*)([A-Za-z_][\w:.-]*)\s*\(\s*\)\s*(.*)$")
FUNCTION_B = re.compile(r"^(\s*)function\s+([A-Za-z_][\w:.-]*)\s*(?:\(\s*\))?\s*(.*)$")
POSITIONAL = re.compile(r"\$\{?([1-9])")
TOKEN = re.compile(
    r"(?:^|[;&|({]|\bthen\b|\bdo\b|\belse\b|\belif\b)\s*"
    r"(?:(?P<open>if|for|while|until|case)|(?P<close>fi|done|esac))\b"
)
BODY_STARTS = ("{", "")


@dataclass
class Header:
    start: int
    indent: str
    name: str
    rest: str


def match_header(number, line):
    for pattern in (FUNCTION_B, FUNCTION_A):
        found = pattern.match(line)
        if found and found.group(3).strip()[:1] in BODY_STARTS:
            return Header(number, found.group(1), found.group(2), found.group(3).strip())
    return None


def depth_changes(line):
    return [1 if found.group("open") else -1 for found in TOKEN.finditer(line)]


class ShellBuilder:
    def __init__(self, raw, masked):
        self.raw = raw
        self.masked = masked

    def run(self):
        functions = []
        for number in range(1, len(self.masked)):
            header = match_header(number, self.masked[number])
            end = self._find_end(header) if header else None
            if end is not None:
                functions.append(self._function(header, end))
        return Structure(functions, [])

    def _find_end(self, header):
        if header.rest.startswith("{") and header.rest.endswith("}") and len(header.rest) > 1:
            return header.start
        closer = re.compile(r"^" + re.escape(header.indent) + r"\}")
        for number in range(header.start + 1, len(self.masked)):
            if closer.match(self.masked[number]):
                return number
        return None

    def _function(self, header, end):
        function = Function(header.name, header.start, header.start, end)
        function.params = self._positional(header.start, end)
        function.max_depth, function.depth_line = self._depth(header.start, end)
        return function

    def _positional(self, start, end):
        highest = 0
        for number in range(start + 1, end + 1):
            if not self.masked[number].strip():
                continue
            for found in POSITIONAL.finditer(self.raw[number]):
                highest = max(highest, int(found.group(1)))
        return [Param("$" + str(index), "", "", "") for index in range(1, highest + 1)]

    def _depth(self, start, end):
        depth = 0
        best = (0, start)
        for number in range(start, end + 1):
            for change in depth_changes(self.masked[number]):
                depth = max(0, depth + change)
                best = max(best, (depth, number), key=lambda pair: pair[0])
        return best


def build_shell(raw, masked):
    return ShellBuilder(raw, masked).run()
