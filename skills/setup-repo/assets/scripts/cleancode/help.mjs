export const USAGE = `usage: code-quality-check.sh [-h]
                          [--staged | --changed [BASE] | --range BASE..HEAD | --hook | --stop-hook | --list-rules]
                          [--all-lines]
                          [FILE ...]
`;

const DESCRIPTION = "Deterministic clean-code checks on the lines you changed.";

const OPTIONS = `positional arguments:
  FILE

options:
  -h, --help            show this help message and exit
  --staged
  --changed [BASE]
  --range BASE..HEAD
  --hook
  --stop-hook
  --list-rules
  --all-lines
`;

const EPILOG = `
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
  Session edit log: \${TMPDIR:-/tmp}/cc-session-<session_id>.edited (per-cwd name without a
  session_id); CC_SESSION_LOG_MAX=500 caps entries; entries and log files older than 7 days go
  --all-lines    treat every line of FILE... as changed (audit mode)
  --list-rules   print the rule catalog as JSON

Env thresholds (defaults from rules/clean-code.md):
  CC_FUNC_WARN=40 CC_FUNC_ERROR=80 CC_PARAMS_ERROR=4 CC_NEST_WARN=3 CC_NEST_ERROR=4
  CC_FILE_WARN=200 CC_FILE_ERROR=400 (only when the change grows the file)
  function-order (warn): a caller sits below its callee, or a private helper sits above a public function
  in the same block (cycles skipped). guard-clause (warn): one if with no else holds the whole body once
  the function reaches 8 logic lines (Python and brace languages).
  Python docstrings on a module, class or function are warnings (docstring); a free-floating string used
  as a comment is an error. Parameter mutation through res, req, ctx, event, self, this or
  ref.current is a warning; any other parameter mutation is an error.
  CC_DISABLE=rule,rule@ext+ext skips named rules (optionally only for extensions); CC_SKIP=1 or CLEAN_CODE_SKIP=1 skips the run

Output: JSON {findings:[{file,line,rule,severity,message,fix_hint}],summary} on stdout, human text on
stderr. Hook modes print only hook protocol output.
Exit: 0 clean (warnings allowed), 1 errors found, 2 usage, 3 precondition (not a git repo, bad BASE).
Hook modes: exit 2 with the findings on stderr feeds them back to the agent.
`;

export const HELP = `${USAGE}\n${DESCRIPTION}\n\n${OPTIONS}\n${EPILOG}`;
