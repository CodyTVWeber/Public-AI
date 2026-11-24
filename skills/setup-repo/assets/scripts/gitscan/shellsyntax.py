import re
import shlex

SEPARATORS = set("();|&\n")
REDIRECT = re.compile(r"^[<>&|]*[<>][<>&|]*$")
ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", re.S)
HEREDOC_OPEN = re.compile(r"(?<!<)<<(?!<)-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
SHELL_HEREDOC = re.compile(r"(^|[\s;&|(])(ba|z|da|k)?sh\b[^<]*<<")
MASK = "$SUBST"
BACKTICKS = re.compile(r"`([^`]*)`")
SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "fish"}
KEYWORDS = {"if", "then", "else", "elif", "while", "until", "do", "!", "{", "}", "time"}
EXPORTERS = {"export", "declare", "typeset", "local", "readonly"}
WRAPPERS = {
    "env": {"-u", "-C", "-S", "--unset", "--chdir", "--split-string"},
    "sudo": {"-u", "-g", "-h", "-p", "-C", "-U", "-r", "-t", "-T"},
    "nice": {"-n"},
    "timeout": {"-s", "-k"},
    "command": set(),
    "exec": {"-a"},
    "nohup": set(),
    "xargs": {"-I", "-n", "-P", "-L", "-d", "-E", "-s"},
    "setsid": set(),
}


def strip_heredocs(text):
    out, pending = [], []
    for line in text.split("\n"):
        if pending:
            if heredoc_body_line(line, pending):
                out.append(line)
            continue
        out.append(line)
        pending.extend(heredoc_openers(line))
    return "\n".join(out)


def heredoc_openers(line):
    runs_shell = SHELL_HEREDOC.search(line) is not None
    return [(match.group(2), runs_shell) for match in HEREDOC_OPEN.finditer(line)]


def heredoc_body_line(line, pending):
    if line.strip() == pending[0][0]:
        pending.pop(0)
        return False
    return pending[0][1]


def dollar_paren_body(text, start):
    depth, pos = 1, start + 2
    while pos < len(text) and depth:
        depth += {"(": 1, ")": -1}.get(text[pos], 0)
        pos += 1
    body = text[start + 2:pos - 1] if depth == 0 else text[start + 2:]
    return body, pos


def subst_bodies(text):
    bodies = BACKTICKS.findall(text)
    pos = text.find("$(")
    while pos >= 0:
        body, _ = dollar_paren_body(text, pos)
        bodies.append(body)
        pos = text.find("$(", pos + 2)
    return bodies


def mask_substitutions(text):
    out, pos = [], 0
    while pos < len(text):
        char = text[pos]
        if char == "\\":
            out.append(text[pos:pos + 2])
            pos += 2
        elif text.startswith("$(", pos):
            out.append(MASK)
            pos = dollar_paren_body(text, pos)[1]
        elif char == "`" and text.find("`", pos + 1) > 0:
            out.append(MASK)
            pos = text.find("`", pos + 1) + 1
        else:
            out.append(char)
            pos += 1
    return "".join(out)


def safe_tokenize(text):
    try:
        return tokenize(text)
    except ValueError:
        return None


def tokenize(text):
    lex = shlex.shlex(text, posix=True, punctuation_chars="();<>|&\n")
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    lex.commenters = ""
    return list(lex)


def segments(tokens):
    seg = []
    for token in tokens:
        if token and set(token) <= SEPARATORS:
            yield seg
            seg = []
        elif not REDIRECT.match(token):
            seg.append(token)
    yield seg
