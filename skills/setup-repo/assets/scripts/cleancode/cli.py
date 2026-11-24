import argparse
import json
import os
import sys

from . import hooks
from .catalog import describe_rules
from .filetargets import file_targets
from .gitdiff import GitError
from .report import exit_code, headline, render_human, skipped_json, to_json
from .runner import analyze_all
from .settings import load_config, skip_reason
from .targets import FileOptions, changed_targets, range_targets, staged_targets

STORE_TRUE = "store_true"
USAGE_ERROR = 2
PRECONDITION_ERROR = 3
EPILOG = """\
Findings count only on lines changed vs HEAD (the whole file when it is new or untracked), so
existing debt stays silent. A function is touched when any of its lines changed.

Modes: FILE... | --staged | --changed [BASE] | --range BASE..HEAD | --hook | --stop-hook | --list-rules
  --staged       index vs HEAD, reading staged content
  --changed      working tree and untracked files vs BASE (default HEAD); manual and CI use
  --range        committed changes only, reading the text at the end ref: no working tree, no
                 untracked files; BASE..END or BASE...END (merge base), END defaults to HEAD;
                 BASE may be a tree such as the empty tree; push gates call this
  --hook         Claude Code PostToolUse: stdin JSON, checks tool_input.file_path, skips files
                 outside any git repo or ignored, appends the path to the session edit log
  --stop-hook    Claude Code Stop: stdin JSON, checks the files in the session edit log that
                 still exist (tracked or untracked); with no log or an empty one, only tracked
                 files with changes, never untracked ones (stop_hook_active true exits 0, so the
                 agent never loops)
  Session edit log: ${TMPDIR:-/tmp}/cc-session-<session_id>.edited (per-cwd name without a
  session_id); CC_SESSION_LOG_MAX=500 caps entries; entries and log files older than 7 days go
  --all-lines    treat every line of FILE... as changed (audit mode)
  --list-rules   print the rule catalog as JSON

Env thresholds (defaults from rules/clean-code.md):
  CC_FUNC_WARN=40 CC_FUNC_ERROR=80 CC_PARAMS_ERROR=4 CC_NEST_WARN=3 CC_NEST_ERROR=4
  CC_FILE_WARN=200 CC_FILE_ERROR=400 (only when the change grows the file)
  Python docstrings on a module, class or function are warnings (docstring); a free-floating string used
  as a comment is an error. Parameter mutation through res, req, ctx, event, self, this or
  ref.current is a warning; any other parameter mutation is an error.
  CC_DISABLE=rule,rule@ext+ext skips named rules (optionally only for extensions); CC_SKIP=1 or CLEAN_CODE_SKIP=1 skips the run

Output: JSON {findings:[{file,line,rule,severity,message,fix_hint}],summary} on stdout, human text on
stderr. Hook modes print only hook protocol output.
Exit: 0 clean (warnings allowed), 1 errors found, 2 usage, 3 precondition (not a git repo, bad BASE).
Hook modes: exit 2 with the findings on stderr feeds them back to the agent.
"""


def build_parser():
    parser = argparse.ArgumentParser(
        prog="code-quality-check.sh",
        description="Deterministic clean-code checks on the lines you changed.",
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("files", nargs="*", metavar="FILE")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--staged", action=STORE_TRUE)
    modes.add_argument("--changed", nargs="?", const="HEAD", metavar="BASE")
    modes.add_argument("--range", metavar="BASE..HEAD")
    modes.add_argument("--hook", action=STORE_TRUE)
    modes.add_argument("--stop-hook", action=STORE_TRUE, dest="stop_hook")
    modes.add_argument("--list-rules", action=STORE_TRUE, dest="list_rules")
    parser.add_argument("--all-lines", action=STORE_TRUE, dest="all_lines")
    return parser


def collect(args):
    if args.staged:
        return staged_targets(os.getcwd())
    if args.changed is not None:
        return changed_targets(os.getcwd(), args.changed)
    if args.range:
        return range_targets(os.getcwd(), args.range)
    return file_targets(args.files, FileOptions(all_lines=args.all_lines))


def report_run(targets, config):
    findings = analyze_all(targets, config)
    sys.stdout.write(to_json(findings, len(targets)) + "\n")
    if findings:
        sys.stderr.write(headline(findings) + "\n" + render_human(findings) + "\n")
    return exit_code(findings)


def run_hook(args, config):
    payload = hooks.read_payload(sys.stdin)
    session = hooks.HookSession(config, sys.stdout, sys.stderr)
    if args.hook:
        return session.post_tool_use(payload)
    return session.stop(payload)


def skip_run(args, reason):
    sys.stderr.write("clean-code: skipped (%s=1)\n" % reason)
    if not (args.hook or args.stop_hook):
        sys.stdout.write(skipped_json() + "\n")
    return 0


def list_rules():
    sys.stdout.write(json.dumps(describe_rules(), indent=2) + "\n")
    return 0


def run_checked(args, config):
    try:
        return report_run(collect(args), config)
    except GitError as error:
        sys.stderr.write("clean-code: %s\n" % error)
        return PRECONDITION_ERROR


def has_mode(args):
    return bool(args.files or args.staged or args.range or args.changed is not None)


def main(argv, env=None):
    env = os.environ if env is None else env
    args = build_parser().parse_args(argv)
    reason = skip_reason(env)
    if reason:
        return skip_run(args, reason)
    if args.list_rules:
        return list_rules()
    config = load_config(env)
    if args.hook or args.stop_hook:
        return run_hook(args, config)
    if not has_mode(args):
        sys.stderr.write("clean-code: give FILE..., --staged or --changed (see -h)\n")
        return USAGE_ERROR
    return run_checked(args, config)
