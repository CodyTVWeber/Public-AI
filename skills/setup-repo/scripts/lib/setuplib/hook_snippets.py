PRE_COMMIT_CALL = "scripts/clean-code/check-clean-code.sh"
PRE_PUSH_CALL = "scripts/clean-code/pre-push-gate.sh"
PRIVACY_CALL = "scripts/check-privacy.sh"
OWN_MARKER = "managed-by: setup-repo"
SHEBANG = "#!/usr/bin/env sh"


def husky_lines(hook, privacy):
    if hook == "pre-commit":
        lines = [PRIVACY_CALL + " || exit $?"] if privacy else []
        return lines + [PRE_COMMIT_CALL + " || exit $?"]
    if hook == "pre-push":
        return [PRE_PUSH_CALL + " || exit $?"]
    return [PRIVACY_CALL + ' --message "$1" || exit $?'] if privacy else []


def husky_marker(hook):
    return {"pre-commit": PRE_COMMIT_CALL, "pre-push": PRE_PUSH_CALL, "commit-msg": PRIVACY_CALL}[hook]


def native_body(hook, privacy):
    lines = [SHEBANG.replace("sh", "bash"), "# " + OWN_MARKER, 'root="$(git rev-parse --show-toplevel)"']
    if hook == "pre-commit":
        if privacy:
            lines.append('[ -x "$root/' + PRIVACY_CALL + '" ] && { "$root/' + PRIVACY_CALL + '" || exit $?; }')
        lines.append('"$root/' + PRE_COMMIT_CALL + '" || exit $?')
    elif hook == "pre-push":
        lines.append('"$root/' + PRE_PUSH_CALL + '" || exit $?')
    else:
        lines.append('"$root/' + PRIVACY_CALL + '" --message "$1" || exit $?')
    lines += ['[ -x "$0.bak" ] && exec "$0.bak" "$@"', "exit 0"]
    return "\n".join(lines) + "\n"


def lefthook_snippet(privacy):
    commit = ["  commands:"]
    if privacy:
        commit += ["    privacy:", "      run: " + PRIVACY_CALL]
    commit += ["    clean-code:", "      run: " + PRE_COMMIT_CALL]
    lines = ["pre-commit:"] + commit + ["pre-push:", "  commands:", "    mr-size:", "      run: " + PRE_PUSH_CALL]
    if privacy:
        lines += ["commit-msg:", "  commands:", "    privacy:", "      run: " + PRIVACY_CALL + " --message {1}"]
    return "\n".join(lines) + "\n"


def precommit_hook(hook_id, entry, stage):
    return ["      - id: " + hook_id, "        name: " + hook_id, "        entry: " + entry, "        language: system",
            "        pass_filenames: false", "        always_run: true", "        stages: [" + stage + "]"]


def precommit_snippet(privacy):
    lines = ["  - repo: local", "    hooks:"]
    if privacy:
        lines += precommit_hook("privacy", PRIVACY_CALL, "pre-commit")
    lines += precommit_hook("clean-code", PRE_COMMIT_CALL, "pre-commit")
    lines += precommit_hook("mr-size", PRE_PUSH_CALL, "pre-push")
    return "\n".join(lines) + "\n"


def calls_snippet(privacy):
    lines = [PRIVACY_CALL] if privacy else []
    lines += [PRE_COMMIT_CALL + "   (pre-commit)", PRE_PUSH_CALL + "   (pre-push)"]
    return "\n".join(lines) + "\n"
