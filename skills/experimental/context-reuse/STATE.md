# Project state

Experimental living state for [context-reuse](context-reuse.md). Keep short (under ~2k tokens). Rewrite in place. Not a repo floor.

## Architecture

- Agent source: `AGENTS.md` plus `rules/`. Vendor files redirect ([agent-source](../../../rules/agent-source.md))
- Portable install: `skills/setup-repo` copies rules, hooks, and checks into other repos
- Privacy gate on commit and push ([PRIVACY.md](../../../PRIVACY.md))
- Docs: current vs dated ([docs-current-or-dated](../../../rules/docs-current-or-dated.md))
- Low-risk repo (`.mr-size` `risk: low`): commit, push, open MR ([commit-and-ship](../../../rules/commit-and-ship.md))
- This skill lives under `skills/experimental/`

## Goals

- Reusable AI engineering: rules, skills, hooks, deterministic checks
- Agents write to the floors on every touched line
- Try session memory here without making it a convention

## Open items

- Whether this skill joins the default set
- Session summaries as work finishes
- Optional `summaries/INDEX.md` if the collection is large

## Constraints

- Public git history is permanent
- No employer fingerprint, secrets, version pins, or personal identity
- Scripts: Bash or JavaScript
- Never dump transcripts into this file or into summaries
- Privacy rules apply to everything committed
- Opt-in only; do not load this folder unless the task uses it

## Pointers

- Protocol: [context-reuse.md](context-reuse.md)
- Summaries: [summaries/](summaries/)
- Session record: [summaries/2026-11-27-context-reuse-experimental.md](summaries/2026-11-27-context-reuse-experimental.md)
