import re
from dataclasses import dataclass

from .model import Function, Structure
from .params import extract_params

DEF = re.compile(r"^\s*def\s+(?:self\.)?(?P<name>[\w?!=]+)\s*(?:\((?P<paren>[^)]*)\)|(?P<bare>[^\n#]*))?")
OPENER = re.compile(r"^\s*(?:(?P<word>if|unless|while|until|case|begin|for|def|class|module)\b)")
ASSIGNED_OPENER = re.compile(r"=\s*(?P<word>if|unless|case|begin|while)\b")
DO_BLOCK = re.compile(r"\bdo\s*(?:\|[^|]*\|)?\s*$")
END = re.compile(r"^\s*end\b")
COUNTED = frozenset({"if", "unless", "while", "until", "case", "begin", "for"})


@dataclass
class Frame:
    word: str
    func: object = None


class RubyBuilder:
    def __init__(self):
        self.stack = []
        self.functions = []

    def run(self, masked):
        for number in range(1, len(masked)):
            self._line(number, masked[number])
        return Structure(self.functions, [])

    def _line(self, number, text):
        if END.match(text):
            self._close(number)
            return
        word = self._opener(text)
        if word == "def":
            self._open_def(number, text)
        elif word:
            self._open_control(number, word)

    def _opener(self, text):
        found = OPENER.match(text) or ASSIGNED_OPENER.search(text)
        if found:
            return found.group("word")
        return "do" if DO_BLOCK.search(text) else None

    def _open_def(self, number, text):
        found = DEF.match(text)
        inner = found.group("paren") or found.group("bare") or ""
        function = Function(found.group("name"), number, number, number)
        function.params = extract_params(inner, "ruby")
        self.functions.append(function)
        self.stack.append(Frame("def", function))

    def _open_control(self, number, word):
        self.stack.append(Frame(word))
        if word not in COUNTED:
            return
        depth = 0
        for frame in reversed(self.stack):
            if frame.word == "def":
                self._apply_depth(frame.func, (depth, number))
                return
            depth += frame.word in COUNTED

    def _apply_depth(self, function, reach):
        depth, number = reach
        if depth > function.max_depth:
            function.max_depth = depth
            function.depth_line = number

    def _close(self, number):
        if not self.stack:
            return
        frame = self.stack.pop()
        if frame.word == "def":
            frame.func.end = number


def build_ruby(masked):
    return RubyBuilder().run(masked)
