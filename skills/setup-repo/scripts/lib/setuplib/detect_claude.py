import re

POINTER_MAX_LINES = 3
COMMENT_RULE = re.compile(r"(?i)\b(always|must|should|every)\b[^.\n]*\b(comments?|javadoc|docstrings?|jsdoc)\b")
POINTER_LINE = re.compile(r"^\s*@AGENTS\.md\s*$")
CI_FILES = (("gitlab", ".gitlab-ci.yml"), ("jenkins", "Jenkinsfile"), ("azure", "azure-pipelines.yml"),
            ("circleci", ".circleci/config.yml"))
INCLUDE_ITEM = re.compile(r"^\s*-\s*(?:local|project|remote|template)\s*:\s*(\S+)")
INCLUDE_BARE = re.compile(r"^\s*-\s+(\S+\.ya?ml)\s*$")


def is_pointer(text):
    lines = [line for line in text.splitlines() if line.strip()]
    return any(POINTER_LINE.match(line) for line in lines) and len(lines) <= POINTER_MAX_LINES


def doc_comment_rules(repo, names):
    hits = []
    for name in names:
        if not repo.has(name):
            continue
        for number, line in enumerate(repo.read(name).splitlines(), 1):
            if COMMENT_RULE.search(line):
                hits.append({"path": name, "line": number, "text": line.strip()[:120]})
    return hits


def hook_events(repo):
    settings = repo.json(".claude/settings.json") if repo.has(".claude/settings.json") else {}
    hooks = settings.get("hooks") if isinstance(settings, dict) else None
    return sorted(hooks) if isinstance(hooks, dict) else []


def detect_claude(repo):
    claude_md = repo.read("CLAUDE.md") if repo.has("CLAUDE.md") else ""
    rules = repo.match(".claude/rules/*.md")
    return {
        "settings": {"present": repo.has(".claude/settings.json"), "hook_events": hook_events(repo)},
        "claude_md": {"present": repo.has("CLAUDE.md"), "pointer_to_agents": bool(claude_md) and is_pointer(claude_md)},
        "agents_md": repo.has("AGENTS.md"),
        "rules": sorted(rules),
        "skills_dir": repo.has(".claude/skills"),
        "skills_linked": sorted(name for name in repo.files if name.startswith(".claude/skills/")),
        "comment_rules": doc_comment_rules(repo, ("AGENTS.md", "CLAUDE.md")),
    }


def gitlab_includes(repo):
    if not repo.has(".gitlab-ci.yml"):
        return []
    found = []
    for line in repo.read(".gitlab-ci.yml").splitlines():
        match = INCLUDE_ITEM.match(line) or INCLUDE_BARE.match(line)
        if match:
            found.append(match.group(1))
    return found


def detect_ci(repo):
    files = [path for _, path in CI_FILES if repo.has(path)]
    files += repo.match(".github/workflows/*.yml") + repo.match(".github/workflows/*.yaml")
    provider = "none"
    if repo.has(".gitlab-ci.yml"):
        provider = "gitlab"
    elif any(name.startswith(".github/workflows/") for name in files):
        provider = "github"
    else:
        provider = next((label for label, path in CI_FILES if repo.has(path)), "none")
    return {"provider": provider, "files": files, "gitlab_includes": gitlab_includes(repo)}


def detect_templates(repo):
    return {"gitlab_mr": sorted(repo.match(".gitlab/merge_request_templates/*")),
            "github_pr": repo.has(".github/pull_request_template.md") or repo.has(".github/PULL_REQUEST_TEMPLATE.md")}
