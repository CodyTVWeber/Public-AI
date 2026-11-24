import re

from .model import Param

IDENT = re.compile(r"[A-Za-z_$][\w$]*")
BOOL_NAME = re.compile(r"^(?:is|has|should|enable)(?:[A-Z_]|$)")
BOOL_TYPES = frozenset({"boolean", "bool"})
BOOL_DEFAULTS = frozenset({"true", "false", "True", "False"})
RECEIVERS = frozenset({"self", "cls", "this"})
DESTRUCTURE_START = "{[("
ARROW_CHARS = "-="
COMPARE_BEFORE = "=!<>"


def split_top_level(text):
    parts = []
    current = []
    depth = 0
    for index, char in enumerate(text):
        depth = max(0, depth + bracket_delta(text, index))
        if char == "," and depth == 0:
            parts.append("".join(current))
            current = []
            continue
        current.append(char)
    parts.append("".join(current))
    return [part.strip() for part in parts if part.strip()]


def bracket_delta(text, index):
    char = text[index]
    if char in "([{":
        return 1
    if char in ")]}":
        return -1
    previous = text[index - 1] if index else " "
    if char == "<":
        return 1 if previous.isalnum() or previous in "_>" else 0
    if char == ">" and previous not in ARROW_CHARS:
        return -1
    return 0


def top_index(text, wanted):
    depth = 0
    for index, char in enumerate(text):
        if depth == 0 and char == wanted and plain_symbol(text, index):
            return index
        depth = max(0, depth + bracket_delta(text, index))
    return -1


def plain_symbol(text, index):
    following = text[index + 1] if index + 1 < len(text) else " "
    previous = text[index - 1] if index else " "
    if text[index] == "=":
        return following not in "=>" and previous not in COMPARE_BEFORE
    return following != ":" and previous != ":"


def untyped_name(head, lang):
    idents = IDENT.findall(head)
    if not idents:
        return "", ""
    if lang == "go":
        return idents[0], " ".join(idents[1:])
    return idents[-1], " ".join(idents[:-1])


def parse_param(raw, lang):
    text = raw.strip()
    equals = top_index(text, "=")
    head = text if equals < 0 else text[:equals].strip()
    default = "" if equals < 0 else text[equals + 1:].strip()
    if head[:1] in DESTRUCTURE_START:
        return Param("", "", default, text)
    colon = top_index(head, ":")
    if colon < 0:
        name, type_text = untyped_name(head, lang)
        return Param(name, type_text, default, text)
    idents = IDENT.findall(head[:colon])
    return Param(idents[-1] if idents else "", head[colon + 1:].strip(), default, text)


def extract_params(inner, lang):
    parsed = [parse_param(part, lang) for part in split_top_level(inner)]
    kept = [param for param in parsed if param.name not in RECEIVERS]
    if len(kept) == 1 and kept[0].name == "void":
        return []
    return kept


def is_bool_flag(param):
    if not BOOL_NAME.match(param.name):
        return False
    words = param.type_text.replace("?", "").split()
    if not words:
        return True
    return words[-1].lower() in BOOL_TYPES or param.default in BOOL_DEFAULTS
