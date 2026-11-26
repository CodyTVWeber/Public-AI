# Agent-neutral names

Generic, reusable assets named for what they do, never for one vendor or agent.

| Instead of | Use |
| --- | --- |
| `claude-setup/` | `AI-setup/` |
| `setup-clean-code` (one feature of wider job) | `setup-repo` (the scope) |
| `grok-helper`, `cursor-rules` | the job: `output-style`, `editor-rules` |

- **Applies to:** dirs, skills, scripts, rules, doc titles any agent can use
- **Exempt:** paths a tool requires (`.claude/`, `CLAUDE.md`, `GEMINI.md`, `.cursor/`, `AGENTS.md`); assets for one product only. Those entry files only redirect ([agent-source.md](agent-source.md))
- **Rename in one pass:** `rg --hidden` (hidden files too: `.claude/settings.json`, `.git/hooks`), then re-run installers
- **Review check:** generic asset whose name carries a vendor → rename before merge
