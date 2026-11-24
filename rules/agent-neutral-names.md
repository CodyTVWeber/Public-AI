# Agent-neutral names

Generic, reusable assets are named for what they do, never for one vendor or agent.

| Instead of | Use |
| --- | --- |
| `claude-setup/` | `AI-setup/` |
| `setup-clean-code` (one feature of a wider job) | `setup-repo` (the scope) |
| `grok-helper`, `cursor-rules` | the job: `output-style`, `editor-rules` |

- **Applies to:** directories, skills, scripts, rules, and doc titles that any agent can use.
- **Exempt:** paths a tool requires (`.claude/`, `CLAUDE.md`, `.cursor/`, `AGENTS.md`) and assets that exist only for one product.
- **Rename in one pass:** search hidden files too (`rg --hidden`: `.claude/settings.json`, `.git/hooks`), then re-run the installers.
- **Review check:** a generic asset whose name carries a vendor is renamed before merge.
