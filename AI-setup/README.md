# Agent setup

Portable global agent rules: density-first, clean-code floor, safe external writes. Rules live in `AGENTS.md`. `CLAUDE.md` only points there.

## Files

| File | Destination | Purpose |
|---|---|---|
| `AGENTS.md` | `~/.claude/AGENTS.md` | Global rules: density, comments, docs, thinking, checks, external systems |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Pointer to `AGENTS.md`. Do not put rules here |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Claude status bar: model, context %, tokens, git branch and dirty flags |
| `../rules/` | load on demand | Repo-independent rules `AGENTS.md` links to |

## Setup

```bash
git clone <this-repo-remote> ~/code/<this-repo>

ln -sf ~/code/<this-repo>/AI-setup/AGENTS.md ~/.claude/AGENTS.md
ln -sf ~/code/<this-repo>/AI-setup/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/code/<this-repo>/AI-setup/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/code/<this-repo>/AI-setup/statusline-command.sh

ln -sfn ~/code/<this-repo>/skills/implement ~/.claude/skills/implement
```

Statusline in `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

Links in `AGENTS.md` to `../rules/` resolve inside this repo. When the file is copied or symlinked elsewhere, copy `rules/` next to it or install the rules per repo with `skills/setup-repo`.

## Behavior

| Rule | Summary |
|---|---|
| Density | Bullets and tables first; bold the load-bearing phrase; no filler |
| Comments | None; extract or rename |
| Docs | Current state, or a dated immutable snapshot |
| Clean code | `code-quality-check.sh`: file size, function order, length, params, nesting, guard wraps |
| Thinking | Telegraphic reasoning, fewest tokens that still decide |
| Checks | Scripts decide mechanical checks; AI judges only the gaps |
| External writes | Ask first; disclose agency |
| Entry points | Thin `CLAUDE.md` / `AGENTS.md`; detail loads on demand |
| Teaching mode | Off by default |
