# Project state

Living high-level state. Keep short (under ~2k tokens). Rewrite in place. Session records: `summaries/` as dated docs ([context-reuse](../rules/context-reuse.md)).

## Architecture

- Agent source: `AGENTS.md` plus `rules/`. Vendor files redirect ([agent-source](../rules/agent-source.md))
- Portable install: `skills/setup-repo` copies rules, hooks, and checks into other repos
- Privacy gate on commit and push ([PRIVACY.md](../PRIVACY.md))
- Docs: current vs dated ([docs-current-or-dated](../rules/docs-current-or-dated.md))
- Low-risk repo (`.mr-size` `risk: low`): commit, push, open MR ([commit-and-ship](../rules/commit-and-ship.md))

## Goals

- Reusable AI engineering: rules, skills, hooks, deterministic checks
- Agents write to the floors on every touched line
- Sessions start from this file plus 1–2 summaries, not from transcripts

## Open items

- Session summaries as work finishes
- Optional `summaries/INDEX.md` if the collection is large

## Constraints

- Public git history is permanent
- No employer fingerprint, secrets, version pins, or personal identity
- Scripts: Bash or JavaScript
- Never dump transcripts into this file or into summaries
- Privacy rules apply to everything committed

## Pointers

- Rules: [rules/README.md](../rules/README.md)
- Summaries: `.ai-context/summaries/`
- Session record: `.ai-context/summaries/2026-11-27-context-reuse.md`
