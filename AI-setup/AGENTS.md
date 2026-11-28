# Global Rules

Portable agent rules. This file is the source. `CLAUDE.md` and `GEMINI.md` only point here ([rules/agent-source.md](../rules/agent-source.md)). Symlink this file and each redirect into that product's user dir.

## Conversation

[rules/conversation.md](../rules/conversation.md): how to interact with a human on every channel (examples, reply density, teaching mode, external writes). Not the PR body template.

## Comments and docs

- No comments: [rules/ban-comments.md](../rules/ban-comments.md). Extract a named function or rename instead
- Docs are current state or a dated snapshot: [rules/docs-current-or-dated.md](../rules/docs-current-or-dated.md)

## Thinking

[rules/ai-thinking-dense.md](../rules/ai-thinking-dense.md): telegraphic reasoning, fewest tokens that still pick the action. Visible replies follow [conversation/reply-density.md](../rules/conversation/reply-density.md).

## Context window

[rules/context-window.md](../rules/context-window.md): working context cap is 175000 tokens (175k) unless a user message, skill, or repo rule names another cap. At the cap, autocompact, then continue. The cap holds when the model window is larger.

## Entry-point files

[rules/agent-source.md](../rules/agent-source.md): edit this file. `CLAUDE.md`, `GEMINI.md`, and any other vendor file only redirect here. Detailed rules live in `rules/` and load on demand.

## Checks

[rules/muscles-and-skeleton.md](../rules/muscles-and-skeleton.md): scripts, CI, and hooks take compute; AI is glue and judgment. Write skills, rules, and hooks that wrap those scripts. [rules/deterministic-checks.md](../rules/deterministic-checks.md): a script decides every check it implements. Run it. AI judges only what no script covers. Clean-code floor: [rules/clean-code.md](../rules/clean-code.md).

## Shell hygiene

- Quote paths that contain spaces: `"path/with spaces"`
- Prefer `rg` / `grep -r`, `find … -exec … +`, and dedicated tools over `xargs` pipelines (each `xargs` can trigger a permission prompt)
- One combined read-only command over many small ones; write and destructive commands are unaffected

## Delegation

- Exploratory searches: parallel cheaper subagents, one per area; the main agent decides and synthesizes
- Large plans: delegate CLI and MCP execution steps to subagents

Full rule: [rules/delegate-work.md](../rules/delegate-work.md).

## Frustration: fix the agent

[rules/frustration-fix-agent.md](../rules/frustration-fix-agent.md): frustration or vague "work harder" → setup tweak, then cleanup rounds across the tree.

## Business capability

Group folders by spoken business domain; lift a shared part, never sink it: [rules/business-capability-structure.md](../rules/business-capability-structure.md).