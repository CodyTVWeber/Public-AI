import { splitlines } from "./util.mjs";

const COMMENT_RULE = /\b(always|must|should|every)\b[^.\n]*\b(comments?|javadoc|docstrings?|jsdoc)\b/i;
const POINTER_LINE = /^\s*@AGENTS\.md\s*$/;
const CI_FILES = [["gitlab", ".gitlab-ci.yml"], ["jenkins", "Jenkinsfile"], ["azure", "azure-pipelines.yml"],
  ["circleci", ".circleci/config.yml"]];
const INCLUDE_ITEM = /^\s*-\s*(?:local|project|remote|template)\s*:\s*(\S+)/;
const INCLUDE_BARE = /^\s*-\s+(\S+\.ya?ml)\s*$/;
const POINTER_MAX_LINES = 3;

export function isPointer(text) {
  const lines = splitlines(text).filter((line) => line.trim());
  return lines.some((line) => POINTER_LINE.test(line)) && lines.length <= POINTER_MAX_LINES;
}

function docCommentRules(repo, names) {
  const hits = [];
  for (const name of names.filter((item) => repo.has(item))) {
    splitlines(repo.read(name)).forEach((line, index) => {
      if (COMMENT_RULE.test(line)) hits.push({ path: name, line: index + 1, text: line.trim().slice(0, 120) });
    });
  }
  return hits;
}

function hookEvents(repo) {
  const settings = repo.has(".claude/settings.json") ? repo.json(".claude/settings.json") : {};
  const hooks = settings.hooks;
  return hooks && typeof hooks === "object" && !Array.isArray(hooks) ? Object.keys(hooks).sort() : [];
}

export function detectClaude(repo) {
  const claudeMd = repo.has("CLAUDE.md") ? repo.read("CLAUDE.md") : "";
  return {
    settings: { present: repo.has(".claude/settings.json"), hook_events: hookEvents(repo) },
    claude_md: { present: repo.has("CLAUDE.md"), pointer_to_agents: Boolean(claudeMd) && isPointer(claudeMd) },
    agents_md: repo.has("AGENTS.md"),
    rules: repo.match(".claude/rules/*.md").sort(),
    skills_dir: repo.has(".claude/skills"),
    skills_linked: repo.files.filter((name) => name.startsWith(".claude/skills/")).sort(),
    comment_rules: docCommentRules(repo, ["AGENTS.md", "CLAUDE.md"]),
  };
}

function gitlabIncludes(repo) {
  if (!repo.has(".gitlab-ci.yml")) return [];
  const found = [];
  for (const line of splitlines(repo.read(".gitlab-ci.yml"))) {
    const match = INCLUDE_ITEM.exec(line) || INCLUDE_BARE.exec(line);
    if (match) found.push(match[1]);
  }
  return found;
}

export function detectCi(repo) {
  const files = CI_FILES.map(([, file]) => file).filter((file) => repo.has(file));
  files.push(...repo.match(".github/workflows/*.yml"), ...repo.match(".github/workflows/*.yaml"));
  let provider;
  if (repo.has(".gitlab-ci.yml")) provider = "gitlab";
  else if (files.some((name) => name.startsWith(".github/workflows/"))) provider = "github";
  else provider = (CI_FILES.find(([, file]) => repo.has(file)) ?? ["none"])[0];
  return { provider, files, gitlab_includes: gitlabIncludes(repo) };
}

export function detectTemplates(repo) {
  return {
    gitlab_mr: repo.match(".gitlab/merge_request_templates/*").sort(),
    github_pr: repo.has(".github/pull_request_template.md") || repo.has(".github/PULL_REQUEST_TEMPLATE.md"),
  };
}
