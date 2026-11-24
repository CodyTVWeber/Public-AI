import json
import os

from . import session
from .filetargets import file_targets
from .gitdiff import GitError
from .report import exit_code, headline, render_human, warnings_of
from .runner import analyze_all
from .targets import FileOptions, tracked_targets

BLOCKING = 2
CONTEXT_KEY = "additionalContext"
HOOK_OPTIONS = FileOptions(skip_ignored=True, require_repo=True)
FIX_PROMPT = "Fix these before continuing (rules/clean-code.md and rules/ban-comments.md):"


def read_payload(stream):
    try:
        data = json.load(stream)
    except ValueError:
        return {}
    return data if isinstance(data, dict) else {}


def advice_body(event, text):
    if event == "PostToolUse":
        return {"hookSpecificOutput": {"hookEventName": event, CONTEXT_KEY: text}}
    return {"systemMessage": text}


def stop_targets(payload):
    logged = session.logged_paths(payload)
    if logged:
        return file_targets(logged, HOOK_OPTIONS)
    return tracked_targets(payload.get("cwd") or os.getcwd())


class HookSession:
    def __init__(self, config, out, err):
        self.config = config
        self.out = out
        self.err = err

    def post_tool_use(self, payload):
        path = (payload.get("tool_input") or {}).get("file_path") or ""
        if not path:
            return 0
        if not os.path.isabs(path):
            path = os.path.join(payload.get("cwd") or os.getcwd(), path)
        targets = file_targets([path], HOOK_OPTIONS)
        if targets:
            session.record(payload, os.path.realpath(path))
        return self._finish("PostToolUse", analyze_all(targets, self.config))

    def stop(self, payload):
        if payload.get("stop_hook_active"):
            return 0
        try:
            targets = stop_targets(payload)
        except GitError:
            return 0
        return self._finish("Stop", analyze_all(targets, self.config))

    def _finish(self, event, findings):
        if exit_code(findings):
            text = headline(findings) + "\n" + FIX_PROMPT + "\n" + render_human(findings)
            self.err.write(text + "\n")
            return BLOCKING
        self._advise(event, warnings_of(findings))
        return 0

    def _advise(self, event, findings):
        if not findings:
            return
        text = headline(findings) + "\n" + render_human(findings)
        self.out.write(json.dumps(advice_body(event, text)) + "\n")
