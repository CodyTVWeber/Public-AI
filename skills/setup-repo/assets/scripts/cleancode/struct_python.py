import re
from dataclasses import dataclass, field

from .model import Block, Function, Structure
from .params import extract_params
from .parens import balanced_inner, statements

DEF = re.compile(r"^(?:async\s+)?def\s+(?P<name>\w+)\s*(?=\()")
CONTROL = re.compile(r"^(?:async\s+)?(?P<word>if|elif|else|for|while|try|except|finally|match)\b")
ONE_LINE_EMPTY = re.compile(r"^except\b[^:]*:\s*(?:pass|\.\.\.)\s*$")
FINALLY = "finally"
KIND_OF = {"try": "try", "except": "catch", "finally": FINALLY}
TRY_KINDS = frozenset({"try", "catch", FINALLY})
COUNTED = TRY_KINDS | {"ctl"}
EMPTY_BODIES = frozenset({"pass", "..."})


@dataclass
class Frame:
    indent: int
    kind: str
    start: int
    func: object = None
    stmts: list = field(default_factory=list)


class PythonBuilder:
    def __init__(self):
        self.stack = []
        self.functions = []
        self.blocks = []
        self.previous_end = 0

    def run(self, items):
        for item in items:
            self._statement(item)
        self._pop_while(lambda frame: True)
        return Structure(self.functions, self.blocks)

    def _statement(self, item):
        self._pop_while(lambda frame: frame.indent >= item.indent)
        self._record(item)
        if not self._open_def(item):
            self._open_control(item)
        self.previous_end = item.end

    def _pop_while(self, condition):
        while self.stack and condition(self.stack[-1]):
            self._apply_pop(self.stack.pop())

    def _apply_pop(self, frame):
        if frame.kind == "fn":
            frame.func.end = self.previous_end
            return
        if frame.kind not in TRY_KINDS:
            return
        empty = frame.kind == "catch" and all(s in EMPTY_BODIES for s in frame.stmts)
        owner = self._owner()
        self.blocks.append(Block(frame.kind, frame.start, self.previous_end, empty, owner))

    def _owner(self):
        for frame in reversed(self.stack):
            if frame.kind == "fn":
                return frame.func
        return None

    def _open_def(self, item):
        found = DEF.match(item.text)
        if not found:
            return False
        inner = balanced_inner(item.text, found.end())
        function = Function(found.group("name"), item.start, item.end, item.end)
        function.params = extract_params(inner[0] if inner else "", "python")
        self.functions.append(function)
        self.stack.append(Frame(item.indent, "fn", item.start, function))
        return True

    def _record(self, item):
        if self.stack:
            self.stack[-1].stmts.append(item.text)

    def _open_control(self, item):
        found = CONTROL.match(item.text)
        if not found:
            return
        word = found.group("word")
        if ONE_LINE_EMPTY.match(item.text):
            self.blocks.append(Block("catch", item.start, item.end, True, self._owner()))
            return
        if not item.text.endswith(":"):
            return
        self.stack.append(Frame(item.indent, KIND_OF.get(word, "ctl"), item.start))
        self._record_depth(item)

    def _record_depth(self, item):
        depth = 0
        for frame in reversed(self.stack):
            if frame.kind == "fn":
                self._apply_depth(frame.func, (depth, item.start))
                return
            depth += frame.kind in COUNTED

    def _apply_depth(self, function, reach):
        depth, line = reach
        if depth > function.max_depth:
            function.max_depth = depth
            function.depth_line = line


def continuation_lines(triples):
    lines = set()
    for start, _, end in triples:
        lines.update(range(start + 1, end + 1))
    return lines


def build_python(masked, triples):
    items = statements(masked, continuation_lines(triples))
    return PythonBuilder().run(items)
