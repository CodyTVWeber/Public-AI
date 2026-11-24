import os
import shlex
from collections import namedtuple

from . import dynamic, forge, gitparse, subcommands
from .shellsyntax import (ASSIGN, EXPORTERS, KEYWORDS, SHELLS, WRAPPERS, mask_substitutions, safe_tokenize,
                          segments, strip_heredocs, subst_bodies)
from .tags import ASK_UNKNOWN, DENY_HOOKSPATH, GATE_TAGS, UNPARSED

MAX_DEPTH = 4
NUMERIC_WRAPPERS = ("timeout", "nice")
EXEC_ENV = {"GIT_EDITOR", "GIT_SEQUENCE_EDITOR", "GIT_PAGER", "GIT_EXTERNAL_DIFF", "GIT_SSH_COMMAND",
            "GIT_ASKPASS", "GIT_PROXY_COMMAND", "EDITOR", "VISUAL", "PAGER"}
EXEC_PRIMARIES = ("-exec", "-execdir", "-ok", "-okdir")
GitCall = namedtuple("GitCall", "sub cfg rest")


def wrapper_span(tail, base):
    n = 0
    while n < len(tail) and (tail[n].startswith("-") or (base in NUMERIC_WRAPPERS and tail[n][:1].isdigit())):
        takes_value = tail[n] in WRAPPERS[base] and n + 1 < len(tail)
        n += 2 if takes_value else 1
    return n


class Scanner:
    def __init__(self, cwd=None, source=""):
        self.found = set()
        self.cwd = cwd
        self.source = source
        self.xargs = False

    def analyze(self, text, depth=0):
        if depth > MAX_DEPTH:
            self.found.add(UNPARSED)
            return
        text = strip_heredocs(text)
        for body in subst_bodies(text):
            self.analyze(body, depth + 1)
        tokens = safe_tokenize(text)
        if tokens is None:
            self.found.add(UNPARSED)
            gitparse.fallback_tags(text, self.found)
            return
        for seg in segments(tokens):
            self.scan_segment(seg, depth)
        self.scan_dynamic_words(text)

    def scan_dynamic_words(self, text):
        tokens = safe_tokenize(mask_substitutions(text))
        for seg in segments(tokens or []):
            words = seg[self.skip_prefix(seg):]
            if words:
                dynamic.note_word(words, self.source, self.found)

    def skip_prefix(self, seg):
        i = 0
        while i < len(seg):
            token = seg[i]
            base = os.path.basename(token)
            if ASSIGN.match(token):
                self.note_assignment(token)
                i += 1
            elif base in KEYWORDS:
                i += 1
            elif base in WRAPPERS:
                self.xargs = self.xargs or base == "xargs"
                i += 1 + wrapper_span(seg[i + 1:], base)
            else:
                break
        return i

    def scan_segment(self, seg, depth):
        start = self.skip_prefix(seg)
        if start >= len(seg):
            return
        words = seg[start:]
        if os.path.basename(words[0]) in EXPORTERS:
            for arg in words[1:]:
                self.note_assignment(arg)
            return
        self.dispatch(words, depth)

    def dispatch(self, words, depth):
        command, args = words[0], words[1:]
        base = os.path.basename(command).lower()
        for arg in args:
            self.note_assignment(arg)
        if base == "git":
            self.scan_git(args, depth)
        elif base.startswith("git-") and base[4:] in subcommands.KNOWN:
            self.scan_git([base[4:]] + args, depth)
        elif base in SHELLS:
            self.scan_shell_c(args, depth)
        elif base == "eval":
            self.analyze(" ".join(args), depth + 1)
        elif base == "find":
            self.scan_find(args, depth)
        elif base in forge.BINS:
            forge.scan(args, self.found)
        dynamic.note_interpreter(words, self.source, self.found)

    def note_assignment(self, token):
        gitparse.note_assign(token, self.found)
        match = ASSIGN.match(token)
        if match and match.group(1) in EXEC_ENV:
            self.analyze(match.group(2), 1)

    def scan_find(self, args, depth):
        for pos, arg in enumerate(args):
            if arg in EXEC_PRIMARIES:
                self.analyze(gitparse.quote_all(args[pos + 1:]), depth + 1)

    def scan_shell_c(self, args, depth):
        for k, arg in enumerate(args):
            if arg.startswith("-") and not arg.startswith("--") and "c" in arg[1:] and k + 1 < len(args):
                self.analyze(args[k + 1], depth + 1)
                dynamic.note_dynamic_code(args[k + 1], self.source, self.found)
                return

    def scan_git(self, args, depth):
        i, cfg = gitparse.split_git_args(args)
        if i >= len(args):
            if self.xargs:
                dynamic.note_stdin_subcommand(self.source, self.found)
            return
        if gitparse.hooks_override(cfg):
            self.found.add(DENY_HOOKSPATH)
        call = GitCall(args[i].lower(), cfg, args[i + 1:])
        for entry in cfg:
            if not entry.lower().startswith("alias."):
                self.analyze(entry.partition("=")[2], depth + 1)
        for command in subcommands.scan(call.sub, call.rest, self.found):
            self.analyze(command, depth + 1)
        if call.sub not in subcommands.KNOWN:
            self.follow_alias(call, depth)

    def follow_alias(self, call, depth):
        value = gitparse.alias_from_config(call.sub, call.cfg)
        if value is None and depth < MAX_DEPTH:
            value = gitparse.alias_from_git(call.sub, self.cwd)
        if value is None or depth >= MAX_DEPTH:
            self.found.add(ASK_UNKNOWN)
        elif value.startswith("!"):
            self.analyze(value[1:] + " " + gitparse.quote_all(call.rest), depth + 1)
        else:
            self.scan_aliased(value, call, depth)

    def scan_aliased(self, value, call, depth):
        try:
            self.scan_git(shlex.split(value) + call.rest, depth + 1)
        except ValueError:
            self.found.add(UNPARSED)
            self.found.add(ASK_UNKNOWN)


def command_tags(command, cwd=None):
    scanner = Scanner(cwd, command)
    scanner.analyze(command)
    return scanner.found


def coarse_fallback(command, found):
    if UNPARSED in found and not GATE_TAGS & found:
        gitparse.coarse_tags(command, found)
