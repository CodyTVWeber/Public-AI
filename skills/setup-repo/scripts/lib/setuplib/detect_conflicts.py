INSTALLED_MARKER = "scripts/clean-code"
RULE_FILES = ("clean-code.md", "ban-comments.md", "small-mrs.md", "docs-current-or-dated.md")


def foreign_hook_conflicts(systems):
    conflicts = []
    for system in systems:
        if system["name"] == "native":
            conflicts.append({"id": "foreign-native-hook", "path": ".git/hooks/" + system["detail"].split(",")[0],
                              "detail": "existing git hook " + system["detail"] + ": chained, never overwritten",
                              "resolution": "hooks-via native keeps it as <name>.bak and runs it after the checks"})
        if system["name"] == "core.hooksPath" and system["detail"] != ".githooks":
            conflicts.append({"id": "foreign-hooks-path", "path": system["detail"],
                              "detail": "core.hooksPath is already " + system["detail"] + ": never overridden",
                              "resolution": "call scripts/clean-code/check-clean-code.sh and pre-push-gate.sh from it"})
    return conflicts


def eslint_conflicts(loose):
    return [{"id": "eslint-" + item["rule"], "path": item["path"],
             "detail": item["rule"] + " allows " + str(item["configured"]) + ", the rule floor is " + str(item["limit"]),
             "resolution": "tighten it, or keep it: the analyzer enforces the floor on changed lines either way"}
            for item in loose]


def comment_conflicts(comment_rules):
    return [{"id": "comment-style-rule", "path": item["path"] + ":" + str(item["line"]),
             "detail": "existing guidance asks for comments: " + item["text"],
             "resolution": "the guardrails ban comments in code you add; reconcile this line by hand"}
            for item in comment_rules]


def rule_conflicts(repo):
    conflicts = []
    for name in RULE_FILES:
        if repo.has(".claude/rules/" + name):
            conflicts.append({"id": "existing-rule", "path": ".claude/rules/" + name,
                              "detail": "rule file exists: kept unless --force when it differs",
                              "resolution": "diff it and keep the stricter value"})
    return conflicts


def detect_conflicts(repo, parts):
    conflicts = foreign_hook_conflicts(parts["hook_systems"])
    conflicts += eslint_conflicts(parts["eslint_loose"])
    conflicts += comment_conflicts(parts["claude"]["comment_rules"])
    conflicts += rule_conflicts(repo)
    claude_md = parts["claude"]["claude_md"]
    if claude_md["present"] and not claude_md["pointer_to_agents"] and not parts["claude"]["agents_md"]:
        conflicts.append({"id": "claude-md-content", "path": "CLAUDE.md",
                          "detail": "CLAUDE.md holds real content and there is no AGENTS.md",
                          "resolution": "the guardrails section is appended to CLAUDE.md"})
    return conflicts
