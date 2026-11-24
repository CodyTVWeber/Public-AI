import json
import sys

from .scanner import UNPARSED, coarse_fallback, command_tags


def read_command(raw):
    try:
        data = json.loads(raw)
    except ValueError:
        return raw, None, True
    if data.get("tool_name", "Bash") != "Bash":
        return None, None, False
    return (data.get("tool_input") or {}).get("command", "") or "", data.get("cwd"), False


def main(argv):
    raw = sys.stdin.read() if not argv else json.dumps({"tool_input": {"command": argv[0]}})
    command, cwd, bad_json = read_command(raw)
    if command is None:
        return 0
    found = command_tags(command, cwd)
    if bad_json:
        found.add(UNPARSED)
    coarse_fallback(command, found)
    for tag in sorted(found):
        print(tag)
    return 0
