const PRE_COMMIT_CALL = "scripts/clean-code/check-clean-code.sh";
const PRE_PUSH_CALL = "scripts/clean-code/pre-push-gate.sh";
const PRIVACY_CALL = "scripts/check-privacy.sh";
export const OWN_MARKER = "managed-by: setup-repo";
export const SHEBANG = "#!/usr/bin/env sh";

export function huskyLines(hook, privacy) {
  if (hook === "pre-commit") {
    const lines = privacy ? [PRIVACY_CALL + " || exit $?"] : [];
    return [...lines, PRE_COMMIT_CALL + " || exit $?"];
  }
  if (hook === "pre-push") return [PRE_PUSH_CALL + " || exit $?"];
  return privacy ? [PRIVACY_CALL + ' --message "$1" || exit $?'] : [];
}

export function huskyMarker(hook) {
  return { "pre-commit": PRE_COMMIT_CALL, "pre-push": PRE_PUSH_CALL, "commit-msg": PRIVACY_CALL }[hook];
}

export function nativeBody(hook, privacy) {
  const lines = [SHEBANG.replace("sh", "bash"), "# " + OWN_MARKER, 'root="$(git rev-parse --show-toplevel)"'];
  if (hook === "pre-commit") {
    if (privacy) lines.push('[ -x "$root/' + PRIVACY_CALL + '" ] && { "$root/' + PRIVACY_CALL + '" || exit $?; }');
    lines.push('"$root/' + PRE_COMMIT_CALL + '" || exit $?');
  } else if (hook === "pre-push") lines.push('"$root/' + PRE_PUSH_CALL + '" || exit $?');
  else lines.push('"$root/' + PRIVACY_CALL + '" --message "$1" || exit $?');
  lines.push('[ -x "$0.bak" ] && exec "$0.bak" "$@"', "exit 0");
  return lines.join("\n") + "\n";
}

export function lefthookSnippet(privacy) {
  const commit = ["  commands:"];
  if (privacy) commit.push("    privacy:", "      run: " + PRIVACY_CALL);
  commit.push("    clean-code:", "      run: " + PRE_COMMIT_CALL);
  const lines = ["pre-commit:", ...commit, "pre-push:", "  commands:", "    mr-size:", "      run: " + PRE_PUSH_CALL];
  if (privacy) lines.push("commit-msg:", "  commands:", "    privacy:", "      run: " + PRIVACY_CALL + " --message {1}");
  return lines.join("\n") + "\n";
}

function precommitHook(hookId, entry, stage) {
  return ["      - id: " + hookId, "        name: " + hookId, "        entry: " + entry, "        language: system",
    "        pass_filenames: false", "        always_run: true", "        stages: [" + stage + "]"];
}

export function precommitSnippet(privacy) {
  const lines = ["  - repo: local", "    hooks:"];
  if (privacy) lines.push(...precommitHook("privacy", PRIVACY_CALL, "pre-commit"));
  lines.push(...precommitHook("clean-code", PRE_COMMIT_CALL, "pre-commit"));
  lines.push(...precommitHook("mr-size", PRE_PUSH_CALL, "pre-push"));
  return lines.join("\n") + "\n";
}

export function callsSnippet(privacy) {
  const lines = privacy ? [PRIVACY_CALL] : [];
  lines.push(PRE_COMMIT_CALL + "   (pre-commit)", PRE_PUSH_CALL + "   (pre-push)");
  return lines.join("\n") + "\n";
}
