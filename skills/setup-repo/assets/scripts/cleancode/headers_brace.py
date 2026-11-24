import re

from .model import Function
from .parens import match_paren
from .params import extract_params

BLOCK = "block"
ARROW = "arrow"
CONTROL_WORDS = frozenset(
    {"if", "for", "while", "switch", "catch", "return", "else", "do", "try",
     "synchronized", "when", "with", "function", "await", "new", "typeof",
     "sizeof", "super", "this", "assert", "foreach", "using", "lock", "fixed",
     "unless", "match", "elseif", "throw", "guard", "defer", "yield", "case"}
)
NON_TYPE_WORDS = frozenset(
    {"return", "new", "else", "throw", "case", "yield", "await", "delete", "goto",
     "typeof", "in", "is", "as"}
)
MODIFIERS = (
    r"(?:public|private|protected|internal|static|final|abstract|synchronized|native"
    r"|virtual|override|sealed|unsafe|extern|inline|async|partial|new|operator"
    r"|default|const|readonly|constexpr|explicit|friend|export|get|set)"
)
KEYWORD_FN = re.compile(
    r"\b(?:fun|func|fn|def|function)\b\s*(?:[<\[][^>\]()]*[>\]]\s*)?"
    r"(?:\([^)]*\)\s*)?(?:[\w.<>?\[\]]+\.)?(?P<name>[A-Za-z_$][\w$]*)\s*"
    r"(?:[<\[][^>\](]*[>\]]\s*)?(?=\()"
)
JS_ARROW = re.compile(
    r"(?P<name>[A-Za-z_$][\w$]*)\s*(?::\s*[^=;(]+?)?\s*=\s*(?:async\s+)?(?=\()"
)
JS_PROPERTY = re.compile(r"(?P<name>[A-Za-z_$][\w$]*)\s*:\s*(?:async\s+)?(?=\()")
JS_METHOD = re.compile(
    r"^\s*(?:" + MODIFIERS + r"\s+)*(?P<name>[A-Za-z_$][\w$]*)\s*(?:<[^>(]*>)?\s*(?=\()"
)
TYPED_METHOD = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:" + MODIFIERS + r"\s+)*"
    r"(?P<type>(?:[\w<>\[\]?.,*&:]+\s+)+)[*&]*(?P<name>[A-Za-z_]\w*)\s*(?=\()"
)
PATTERNS = {
    "js": ((KEYWORD_FN, BLOCK), (JS_ARROW, ARROW), (JS_PROPERTY, ARROW), (JS_METHOD, BLOCK)),
    "java": ((TYPED_METHOD, BLOCK),),
    "cs": ((TYPED_METHOD, BLOCK),),
    "c": ((TYPED_METHOD, BLOCK),),
    "cpp": ((TYPED_METHOD, BLOCK),),
}
DEFAULT_PATTERNS = ((KEYWORD_FN, BLOCK),)
ARROW_TOKEN = "=>"
EXPRESSION = "expression"
AFTER_ARROW = "brace-after-arrow"
NEXT_LINE = "next-line"
LOOKAHEAD_LINES = 2


def find_body(masked, position, kind):
    line, col = position
    rest = masked[line][col:]
    found = scan_rest(rest, kind)
    if found is None:
        return None
    if found == "{":
        return (line, col + rest.index("{"))
    if found == EXPRESSION:
        return EXPRESSION
    if found == AFTER_ARROW:
        return (line, col + rest.index("{", rest.index(ARROW_TOKEN)))
    return next_line_brace(masked, line)


def scan_rest(rest, kind):
    if kind == ARROW:
        return scan_arrow(rest, rest.find(ARROW_TOKEN))
    stop = first_of(rest, "{;")
    equals = first_assignment(rest)
    if stop >= 0 and (equals < 0 or stop < equals):
        return "{" if rest[stop] == "{" else None
    if equals >= 0:
        return EXPRESSION
    return NEXT_LINE


def scan_arrow(rest, arrow):
    if arrow < 0:
        return None
    after = rest[arrow + len(ARROW_TOKEN):].strip()
    return AFTER_ARROW if after.startswith("{") else EXPRESSION


def first_of(text, chars):
    hits = [text.index(char) for char in chars if char in text]
    return min(hits) if hits else -1


def first_assignment(text):
    for index, char in enumerate(text):
        if char == "=" and text[index + 1:index + 2] not in ("=", ">"):
            return index
    return -1


def next_line_brace(masked, line):
    for number in range(line + 1, min(len(masked), line + 1 + LOOKAHEAD_LINES)):
        stripped = masked[number].strip()
        if stripped:
            return (number, masked[number].index("{")) if stripped.startswith("{") else None
    return None


def acceptable(match):
    if match.group("name") in CONTROL_WORDS:
        return False
    type_text = match.groupdict().get("type")
    return not type_text or type_text.split()[0] not in NON_TYPE_WORDS


class HeaderDetector:
    def __init__(self, masked, lang):
        self.masked = masked
        self.lang = lang
        self.patterns = PATTERNS.get(lang, DEFAULT_PATTERNS)

    def detect(self):
        found = []
        for number in range(1, len(self.masked)):
            if not self.masked[number].strip():
                continue
            built = self._first_function(number)
            if built is not None:
                found.append(built)
        return found

    def _first_function(self, number):
        for pattern, kind in self.patterns:
            match = pattern.search(self.masked[number])
            if match is None or not acceptable(match):
                continue
            built = self._build(number, (match, kind))
            if built is not None:
                return built
        return None

    def _build(self, line, hit):
        match, kind = hit
        span = match_paren(self.masked, (line, match.end()))
        if span is None:
            return None
        inner, end_line, end_col = span
        body = find_body(self.masked, (end_line, end_col + 1), kind)
        if body is None:
            return None
        function = Function(match.group("name"), line, end_line, end_line)
        function.params = extract_params(inner, self.lang)
        return function, None if body == EXPRESSION else body


def detect_headers(masked, lang):
    return HeaderDetector(masked, lang).detect()
