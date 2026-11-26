const PROJECT_DIR_VAR = '"$CLAUDE_PROJECT_DIR"';
export const PROJECT_DIR = PROJECT_DIR_VAR;
const ANALYZER = PROJECT_DIR + "/scripts/clean-code/code-quality-check.sh";
const WRITE_MATCHER = "Write|Edit|MultiEdit";

const spec = ([event, matcher, command, timeout]) => ({ event, matcher, command, timeout });
const cleanCode = (name) => PROJECT_DIR + "/scripts/clean-code/" + name;
const guard = (name) => PROJECT_DIR + "/scripts/guard/" + name;

export const GROUPS = {
  guard: [spec(["PreToolUse", "Bash", cleanCode("claude-pre-tool-guard.sh"), 20])],
  "docs-lint": [spec(["PostToolUse", "Write|Edit", cleanCode("lint-docs.sh") + " --hook", 10])],
  analyzer: [spec(["PostToolUse", WRITE_MATCHER, ANALYZER + " --hook", 20])],
  stop: [spec(["Stop", null, ANALYZER + " --stop-hook", 60])],
  "post-git": [spec(["PostToolUse", "Bash", cleanCode("post-git-check.sh"), 20])],
  "approval-gate": [spec(["PreToolUse", "Bash", guard("git-approval-guard.sh"), 10])],
  "research-ref": [spec(["SessionStart", null, guard("research-ref.sh") + " --hook", 20])],
};

export function specsFor(names) {
  const unknown = names.filter((name) => !(name in GROUPS));
  if (unknown.length) throw new Error(unknown.join(", "));
  return names.flatMap((name) => GROUPS[name]);
}
