const RULE_FILES = ["clean-code.md", "ban-comments.md", "ban-workbenches.md", "small-mrs.md", "docs-current-or-dated.md"];

function foreignHookConflicts(systems) {
  const conflicts = [];
  for (const system of systems) {
    if (system.name === "native") {
      conflicts.push({ id: "foreign-native-hook", path: ".git/hooks/" + system.detail.split(",")[0],
        detail: "existing git hook " + system.detail + ": chained, never overwritten",
        resolution: "hooks-via native keeps it as <name>.bak and runs it after the checks" });
    }
    if (system.name === "core.hooksPath" && system.detail !== ".githooks") {
      conflicts.push({ id: "foreign-hooks-path", path: system.detail,
        detail: "core.hooksPath is already " + system.detail + ": never overridden",
        resolution: "call scripts/clean-code/check-clean-code.sh and pre-push-gate.sh from it" });
    }
  }
  return conflicts;
}

const eslintConflicts = (loose) => loose.map((item) => ({
  id: "eslint-" + item.rule, path: item.path,
  detail: item.rule + " allows " + item.configured + ", the rule floor is " + item.limit,
  resolution: "tighten it, or keep it: the analyzer enforces the floor on changed lines either way",
}));

const commentConflicts = (rules) => rules.map((item) => ({
  id: "comment-style-rule", path: item.path + ":" + item.line,
  detail: "existing guidance asks for comments: " + item.text,
  resolution: "the guardrails ban comments in code you add; reconcile this line by hand",
}));

const ruleConflicts = (repo) => RULE_FILES.filter((name) => repo.has(".claude/rules/" + name)).map((name) => ({
  id: "existing-rule", path: ".claude/rules/" + name,
  detail: "rule file exists: kept unless --force when it differs", resolution: "diff it and keep the stricter value",
}));

export function detectConflicts(repo, parts) {
  const conflicts = [...foreignHookConflicts(parts.hook_systems), ...eslintConflicts(parts.eslint_loose),
    ...commentConflicts(parts.claude.comment_rules), ...ruleConflicts(repo)];
  const claudeMd = parts.claude.claude_md;
  if (claudeMd.present && !claudeMd.pointer_to_agents && !parts.claude.agents_md) {
    conflicts.push({ id: "claude-md-content", path: "CLAUDE.md",
      detail: "CLAUDE.md holds real content and there is no AGENTS.md",
      resolution: "the guardrails section is appended to CLAUDE.md" });
  }
  return conflicts;
}
