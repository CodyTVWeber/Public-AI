# Agent setup

Portable global agent rules: density-first, clean-code floor, safe external writes. Rules live in `AGENTS.md`. Each product file only redirects there ([rules/agent-source.md](../rules/agent-source.md)).

## Files

| File | Destination | Purpose |
|---|---|---|
| `AGENTS.md` | `<product-home>/AGENTS.md` | Generic rules: density, comments, docs, thinking, checks, frustration, external systems |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Redirect to `AGENTS.md` |
| `GEMINI.md` | `~/.gemini/GEMINI.md` | Redirect to `AGENTS.md` |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Claude status bar: model, context %, tokens, git branch and dirty flags |
| `../rules/` | load on demand | Repo-independent rules `AGENTS.md` links to |

Products that already read `AGENTS.md` (Cursor, Codex, Copilot) get that file only.

## Setup

```bash
git clone <this-repo-remote> ~/code/<this-repo>
repo=~/code/<this-repo>

link_home() {
  mkdir -p "$1"
  ln -sfn "$repo/AI-setup/AGENTS.md" "$1/AGENTS.md"
  ln -sfn "$repo/AI-setup/$2" "$1/$2"
}
link_home ~/.claude CLAUDE.md
link_home ~/.gemini GEMINI.md

ln -sfn "$repo/AI-setup/statusline-command.sh" ~/.claude/statusline-command.sh
chmod +x "$repo/AI-setup/statusline-command.sh"
ln -sfn "$repo/skills/implement" ~/.claude/skills/implement
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
| Entry points | Edit `AGENTS.md` only; vendor files redirect there |
| Frustration | Vague harder or frustration → setup tweak, then cleanup rounds (extract copies, domain grouping, reference screen) |
| Teaching mode | Off by default |
