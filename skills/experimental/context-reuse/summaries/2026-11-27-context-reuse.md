Date: 2026-11-27

As of 2026-11-27 this repo keeps session memory in `.ai-context/`.

## Goal

Ship context reuse as a `rules/` floor that matches this repo, not a pasted `AGENTS.md` dump.

## Decisions

- Rule: `rules/context-reuse.md`. `AGENTS.md` points at it from Pointers and Rules
- `STATE.md` is a Current doc of this repo; summaries are Dated (`Date:` header, immutable)
- Extend by writing a superseding dated file, not by editing an existing summary
- `setup-repo` ships the rule with the other `rules/*.md` copies

## Open items

- Fill summaries as sessions finish
- Optional `INDEX.md` if the folder is large

## Facts and locations

- Rule: `rules/context-reuse.md`
- State: `.ai-context/STATE.md`
- Summaries: `.ai-context/summaries/`

## Related

- `rules/docs-current-or-dated.md`
- `rules/research-latest-main.md`
