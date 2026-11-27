# Context reuse

Experimental session memory in this folder. Opt-in. Not a `rules/` floor. Load `STATE.md` only. Retrieve summaries by need. Never dump transcripts.

| Path | Kind | Role |
|---|---|---|
| `STATE.md` | Current | Architecture, goals, open items, constraints. Rewrite in place. Keep under ~2k tokens |
| `summaries/YYYY-MM-DD-<slug>.md` | Dated | One session or slice. `Date:` header. Immutable except typos ([docs-current-or-dated](../../../rules/docs-current-or-dated.md)) |
| `summaries/INDEX.md` | Current | Optional table when the folder is large |

## Session start

1. Read `STATE.md`
2. Task matches prior work → list or search `summaries/`; read 1–2 files (else the 2–3 with the latest `YYYY-MM-DD-` prefix)
3. Continue from a named summary. Do not rebuild from transcripts
4. Research still fetches the default branch ([research-latest-main](../../../rules/research-latest-main.md))

## During work and session end

- `STATE.md` is the living source; update it when a future session needs the fact
- Host-repo privacy and docs rules apply to every committed file
- Write `summaries/YYYY-MM-DD-<slug>.md`: Goal · Decisions · Open items · Facts and locations · Related. 300–800 tokens
- High-level state changed → update `STATE.md`
- Do not edit an existing summary. Dated docs are immutable; write a superseding file (`Supersedes:`)
- Inject `STATE.md` + 1–2 summaries, not history. Living fact → `STATE.md`; dated file is the record

## Enforcement

Review only. Missing or stale files do not fail a check. `lint-docs.sh` still enforces Current vs Dated on the Markdown.
