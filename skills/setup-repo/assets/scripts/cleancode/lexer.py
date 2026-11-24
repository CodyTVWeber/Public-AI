import re

from .languages import TRIPLE_LENGTH

HEREDOC = re.compile(r"(?<!<)<<(?!<)[-~]?\s*(['\"]?)([A-Za-z_]\w*)\1")
RUST_CHAR = re.compile(r"'(?:\\[^']*|[^'\\])'")
WORD_START = " \t;|&("
BLOCK_NOISE = "*"
ESCAPE = "\\"


class Scanner:
    def __init__(self, spec, comment_type):
        self.spec = spec
        self.comment_type = comment_type
        self.block_close = None
        self.seg_col = 0
        self.quote = None
        self.str_start = (0, 0)
        self.str_buf = []
        self.heredoc = None
        self.line_block_open = False
        self.lineno = 0
        self.line = ""
        self.cells = []
        self.comments = []
        self.strings = []
        self.triples = []

    def feed(self, line, lineno):
        self.lineno = lineno
        self.line = line
        if self.heredoc is not None:
            return self._heredoc_line()
        if self._in_line_block():
            return " " * len(line)
        self.cells = list(line)
        position = 0
        while position < len(line):
            position = self._step(position)
        self._end_line()
        self._detect_heredoc()
        return "".join(self.cells)

    def _mask(self, start, stop):
        for index in range(start, min(stop, len(self.cells))):
            self.cells[index] = " "

    def _add_comment(self, col, text):
        self.comments.append(self.comment_type(self.lineno, col, text))

    def _step(self, position):
        if self.block_close is not None:
            return self._block(position)
        if self.quote is not None:
            return self._string(position)
        return self._code(position)

    def _code(self, position):
        line = self.line
        if line[position] == ESCAPE:
            return position + 2
        if self.spec.rust_chars and line[position] == "'":
            return self._rust_char(position)
        prefix = self._comment_prefix(position)
        if prefix:
            return self._line_comment(position, prefix)
        block = self.spec.block
        if block and line.startswith(block[0], position):
            self.block_close = block[1]
            self.seg_col = position
            return self._block(position + len(block[0]))
        quote = self._quote_at(position)
        if quote is None:
            return position + 1
        return self._open_string(position, quote)

    def _rust_char(self, position):
        found = RUST_CHAR.match(self.line, position)
        if not found:
            return position + 1
        self._mask(position + 1, found.end() - 1)
        return found.end()

    def _comment_prefix(self, position):
        for prefix in self.spec.line_comments:
            if self.line.startswith(prefix, position) and self._comment_ok(position):
                return prefix
        return None

    def _comment_ok(self, position):
        before = self.line[position - 1] if position else " "
        if self.spec.word_start_comment:
            return before in WORD_START
        if self.spec.url_guard:
            return before != ":"
        return True

    def _line_comment(self, position, prefix):
        self._add_comment(position, self.line[position + len(prefix):].strip())
        self._mask(position, len(self.line))
        return len(self.line)

    def _block(self, position):
        line = self.line
        close = line.find(self.block_close, position)
        stop = len(line) if close < 0 else close
        self._add_comment(self.seg_col, line[position:stop].strip().lstrip(BLOCK_NOISE).strip())
        end = len(line) if close < 0 else close + len(self.block_close)
        self._mask(self.seg_col, end)
        if close >= 0:
            self.block_close = None
        return end

    def _quote_at(self, position):
        for triple in self.spec.triples:
            if self.line.startswith(triple, position):
                return triple
        char = self.line[position]
        return char if char in self.spec.quotes else None

    def _open_string(self, position, quote):
        self.quote = quote
        self.str_start = (self.lineno, position)
        self.str_buf = []
        return self._string(position + len(quote))

    def _string(self, position):
        line = self.line
        raw = self.quote in self.spec.raw
        cursor = position
        while cursor < len(line):
            if line[cursor] == ESCAPE and not raw:
                cursor += 2
                continue
            if line.startswith(self.quote, cursor):
                return self._close_string(position, cursor)
            cursor += 1
        self._take(position, len(line))
        return len(line)

    def _take(self, start, stop):
        self.str_buf.append(self.line[start:stop])
        self._mask(start, stop)

    def _close_string(self, start, stop):
        self._take(start, stop)
        quote = self.quote
        self.quote = None
        content = "".join(self.str_buf)
        if len(quote) == TRIPLE_LENGTH:
            self.triples.append((self.str_start[0], self.str_start[1], self.lineno))
        elif content:
            self.strings.append((self.str_start[0], content))
        return stop + len(quote)

    def _end_line(self):
        self.seg_col = 0
        if self.quote is None or self._string_continues():
            return
        self.quote = None

    def _string_continues(self):
        if len(self.quote) == TRIPLE_LENGTH or self.quote in self.spec.multiline:
            return True
        return self.line.rstrip().endswith(ESCAPE)

    def _in_line_block(self):
        if not self.spec.line_block:
            return False
        opener, closer = self.spec.line_block
        if not self.line_block_open and not self.line.startswith(opener):
            return False
        self.line_block_open = not self.line.startswith(closer)
        self._add_comment(0, self.line.strip())
        return True

    def _detect_heredoc(self):
        if not self.spec.heredoc or self.quote or self.block_close:
            return
        for found in HEREDOC.finditer(self.line):
            if self.cells[found.start()] == "<":
                self.heredoc = found.group(2)
                return

    def _heredoc_line(self):
        if self.line.strip() == self.heredoc:
            self.heredoc = None
        return " " * len(self.line)
