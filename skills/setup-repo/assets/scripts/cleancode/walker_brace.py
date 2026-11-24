import re
from dataclasses import dataclass

from .model import Block

FINALLY = "finally"
COUNTED = frozenset({"ctl", "try", "catch", FINALLY})
TRY_KINDS = frozenset({"try", "catch", FINALLY})
KIND_PATTERNS = (
    ("catch", re.compile(r"\bcatch\b")),
    (FINALLY, re.compile(r"\bfinally\b")),
    ("try", re.compile(r"\btry\b")),
    (
        "ctl",
        re.compile(
            r"\b(?:if|elseif|elif|else(?!\s*->)|for|foreach|while|do|switch|when"
            r"|loop|match|guard|unless)\b"
        ),
    ),
)


@dataclass
class Frame:
    kind: str
    start: int
    func: object
    content: bool = False


class Walker:
    def __init__(self, opens):
        self.opens = opens
        self.stack = []
        self.blocks = []
        self.prefix = []
        self.parens = 0

    def run(self, masked):
        for number in range(1, len(masked)):
            self._line(number, masked[number])
        for frame in self.stack:
            self._apply_frame_end(frame, len(masked) - 1)
        return self.blocks

    def _line(self, number, text):
        for col, char in enumerate(text):
            if char == "{":
                self._open(number, col)
            elif char == "}":
                self._close(number)
            else:
                self._other(char)
        self.prefix.append(" ")

    def _other(self, char):
        if char == "(":
            self.parens += 1
        elif char == ")":
            self.parens = max(0, self.parens - 1)
        if char == ";" and self.parens == 0:
            self.prefix = []
            return
        if not char.isspace() and self.stack:
            self.stack[-1].content = True
        self.prefix.append(char)

    def _open(self, number, col):
        if self.stack:
            self.stack[-1].content = True
        kind, func = self._classify(number, col)
        self.stack.append(Frame(kind, number, func))
        self.prefix = []
        if kind in COUNTED:
            self._record_depth(number)

    def _classify(self, number, col):
        func = self.opens.get((number, col))
        if func is not None:
            return "fn", func
        text = "".join(self.prefix)
        for kind, pattern in KIND_PATTERNS:
            if pattern.search(text):
                return kind, None
        return "plain", None

    def _record_depth(self, number):
        depth = 0
        for frame in reversed(self.stack):
            if frame.kind == "fn":
                self._apply_depth(frame.func, (depth, number))
                return
            depth += frame.kind in COUNTED

    def _apply_depth(self, func, reach):
        depth, number = reach
        if depth > func.max_depth:
            func.max_depth = depth
            func.depth_line = number

    def _close(self, number):
        self.prefix = []
        if not self.stack:
            return
        self._apply_frame_end(self.stack.pop(), number)

    def _apply_frame_end(self, frame, number):
        if frame.kind == "fn":
            frame.func.end = number
        if frame.kind in TRY_KINDS:
            owner = next((f.func for f in reversed(self.stack) if f.kind == "fn"), None)
            self.blocks.append(Block(frame.kind, frame.start, number, not frame.content, owner))
