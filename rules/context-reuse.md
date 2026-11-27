# Context reuse

Git-native session memory in `.ai-context/`. Load `STATE.md` only. Retrieve summaries by need. Never dump transcripts.

| Path | Kind | Role |
|---|---|---|
| `.ai-context/STATE.md` | Current | Architecture, goals, open items, constraints. Rewrite in place. Keep under ~2k tokens |
| `.ai-context/summaries/YYYY-MM-DD-<slug>.md` | Dated | One session or slice. `Date:` header. Immutable except typos ([docs-current-or-dated](docs-current-or-dated.md)) |
| `.ai-context/summaries/INDEX.md` | Current | Optional table when the folder is large |

Missing `.ai-context/`: create `STATE.md` and `summaries/` on first write.

## Session start

1. Read `STATE.md`
2. Task matches prior work → list or search `summaries/`; read 1–2 files (else the 2–3 with the latest `YYYY-MM-DD-` prefix)
3. Continue from a named summary. Do not rebuild from transcripts
4. Research still fetches the default branch ([research-latest-main](research-latest-main.md))

## During work and session end

- `STATE.md` is the living source; update it when a future session needs the fact
- Host-repo privacy and docs rules apply to every committed file
- Write `.ai-context/summaries/YYYY-MM-DD-<slug>.md`: Goal · Decisions · Open items · Facts and locations · Related. 300–800 tokens
- High-level state changed → update `STATE.md`
- Do not edit an existing summary. Dated docs are immutable; write a superseding file (`Supersedes:`)
- Inject `STATE.md` + 1–2 summaries, not history. Living fact → `STATE.md`; dated file is the record

## Enforcement

Review: stale `STATE.md`; missing summary after meaningful work; transcript dumps. `lint-docs.sh` enforces Current vs Dated.
