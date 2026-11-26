from collections import namedtuple

HookSpec = namedtuple("HookSpec", "event matcher command timeout")

PROJECT_DIR = '"$CLAUDE_PROJECT_DIR"'
ANALYZER = PROJECT_DIR + "/scripts/clean-code/code-quality-check.sh"
WRITE_MATCHER = "Write|Edit|MultiEdit"
ANALYZER_TIMEOUT = 20
STOP_TIMEOUT = 60
POST_GIT_TIMEOUT = 20
GUARD_TIMEOUT = 20
APPROVAL_TIMEOUT = 10
DOCS_LINT_TIMEOUT = 10
SESSION_TIMEOUT = 20


def clean_code(name):
    return PROJECT_DIR + "/scripts/clean-code/" + name


def guard(name):
    return PROJECT_DIR + "/scripts/guard/" + name


GROUPS = {
    "guard": [HookSpec("PreToolUse", "Bash", clean_code("claude-pre-tool-guard.sh"), GUARD_TIMEOUT)],
    "docs-lint": [HookSpec("PostToolUse", "Write|Edit", clean_code("lint-docs.sh") + " --hook", DOCS_LINT_TIMEOUT)],
    "analyzer": [HookSpec("PostToolUse", WRITE_MATCHER, ANALYZER + " --hook", ANALYZER_TIMEOUT)],
    "stop": [HookSpec("Stop", None, ANALYZER + " --stop-hook", STOP_TIMEOUT)],
    "post-git": [HookSpec("PostToolUse", "Bash", clean_code("post-git-check.sh"), POST_GIT_TIMEOUT)],
    "approval-gate": [HookSpec("PreToolUse", "Bash", guard("git-approval-guard.sh"), APPROVAL_TIMEOUT)],
    "research-ref": [HookSpec("SessionStart", None, guard("research-ref.sh") + " --hook", SESSION_TIMEOUT)],
}
DEFAULT_GROUPS = ("guard", "docs-lint", "analyzer", "stop", "post-git")


def specs_for(names):
    unknown = [name for name in names if name not in GROUPS]
    if unknown:
        raise KeyError(", ".join(unknown))
    return [spec for name in names for spec in GROUPS[name]]
