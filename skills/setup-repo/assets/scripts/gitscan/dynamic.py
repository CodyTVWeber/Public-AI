import os
import re

from .shellsyntax import SHELLS
from .tags import ASK_DYNAMIC, ASK_INTERPRETER

ACTIONS = r"(commit|push|merge|cherry-pick|revert|send-pack|update-ref|commit-tree)"
FORGE_ACTIONS = r"(gh|glab)\b[^\n;&|]*(\b(merge|create)\b|-X\s*(POST|PUT|PATCH|DELETE)|--method)"
STRICT_TEXT = re.compile(r"\bgit\b[^\n;&|]*\b" + ACTIONS + r"\b|\b" + FORGE_ACTIONS, re.I)
LOOSE_TEXT = re.compile(r"\bgit\b[\s\S]*\b" + ACTIONS + r"\b|\b" + FORGE_ACTIONS, re.I)
GIT_WORD = re.compile(r"\bgit\b", re.I)
ANYWHERE_TEXT = re.compile(r"\b" + ACTIONS + r"\b", re.I)
KEYWORD_ARG = re.compile(r"^(commit|push|merge|cherry-pick|revert|rebase|am|send-pack|update-ref|commit-tree)$")
INTERPRETER = re.compile(r"^(sh|bash|zsh|dash|ksh|fish|csh|tcsh|python[0-9.]*|perl|ruby|node|nodejs|deno|bun|php|lua|awk|gawk|osascript|eval|source|\.)$")
INLINE_FLAG = re.compile(r"^-[a-zA-Z]*[ceEr]$|^--eval$|^--print$")
BRACE = re.compile(r"\{[^{}]*(,|\.\.)[^{}]*\}")
GLOB = re.compile(r"[*?\[]")
STDIN_ARGS = {"-", "-s", "/dev/stdin", "/dev/fd/0"}
AWKS = ("awk", "gawk")


def is_dynamic(word):
    if word in ("[", "[["):
        return False
    return "$" in word or "`" in word or bool(BRACE.search(word)) or bool(GLOB.search(word))


def note_word(words, source, found):
    if not is_dynamic(words[0]):
        return
    named = ANYWHERE_TEXT.search(words[0]) or any(KEYWORD_ARG.match(arg) for arg in words[1:])
    if named or (GIT_WORD.search(source) and ANYWHERE_TEXT.search(source)):
        found.add(ASK_DYNAMIC)


def inline_text(base, args):
    if base == "eval":
        return " ".join(args)
    if base in AWKS:
        programs = [arg for arg in args if not arg.startswith("-")]
        return programs[0] if programs else None
    for pos, arg in enumerate(args):
        if INLINE_FLAG.match(arg):
            return " ".join(args[pos + 1:])
    return None


def reads_stdin(base, args, source):
    if any(arg in STDIN_ARGS for arg in args) or all(arg.startswith("-") for arg in args):
        return True
    return re.search(r"\b" + re.escape(base) + r"\b[^\n;&|]*<", source) is not None


def is_dynamic_text(code):
    return "$" in code or "`" in code


def note_inline_code(code, source, found):
    text = source if is_dynamic_text(code) else code
    if LOOSE_TEXT.search(text):
        found.add(ASK_INTERPRETER)


def note_dynamic_code(code, source, found):
    if is_dynamic_text(code):
        note_inline_code(code, source, found)


def note_interpreter(words, source, found):
    base = os.path.basename(words[0]).lower()
    if not INTERPRETER.match(base):
        return
    args = words[1:]
    inline = None if base in SHELLS else inline_text(base, args)
    if inline is not None:
        note_inline_code(inline, source, found)
    elif reads_stdin(base, args, source) and STRICT_TEXT.search(source):
        found.add(ASK_INTERPRETER)


def note_stdin_subcommand(source, found):
    if ANYWHERE_TEXT.search(source):
        found.add(ASK_INTERPRETER)
