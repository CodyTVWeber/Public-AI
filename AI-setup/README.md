# Claude / agent setup

Portable global agent rules: density-first, clean-code floor, safe external writes.

## Files

| File | Destination | Purpose |
|---|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Global rules: density, comments, docs, file size, external systems, structure |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Status bar: model, context %, tokens, git branch and dirty flags |
| `../rules/` | load on demand | Repo-independent rules the global file links to |

## Setup

```bash
git clone <this-repo-remote> ~/code/<this-repo>

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

Links in `CLAUDE.md` to `../rules/` resolve inside this repo. When the file is copied or symlinked elsewhere, copy `rules/` next to it or install the rules per repo with `skills/setup-repo`.

## Behavior

| Rule | Summary |
|---|---|
| Density | Bullets and tables first; bold the load-bearing phrase; no filler |
| Comments | None; extract or rename |
| Docs | Current state, or a dated immutable snapshot |
| File size | ≤ ~200 lines, soft |
| External writes | Ask first; disclose agency |
| Entry points | Thin `CLAUDE.md` / `AGENTS.md`; detail loads on demand |
| Teaching mode | Off by default |
