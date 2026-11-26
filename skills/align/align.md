---
name: align
description: Get AI and human on the same picture of a task or document before planning: spec, ADRs, glossary, one-page alignment brief, reusing related docs. Use for "align on", /align, a large or vague task, a UI task with a design, or phase A0 of the plan-implement-review chain (apirw).
argument-hint: "<task or path to a document> [topic=<slug>]"
---

# Align

Close the gap between what the human means and what the AI heard, in writing, before `write-plan` runs. Docs only: no code changes, no branch, no PR.

## Outputs

Per topic dir, default `docs/align/<topic>/`. Working notes only: never committed. `scripts/new-doc.sh` detects repo doc layout (`docs/`, `doc/`, shared `docs/adr/` or `adr/`) and prints `convention`: tell the human which it chose.

| Doc | Kind | Holds |
|---|---|---|
| `spec.md` | Current | goal, users, scope, non-goals, numbered acceptance criteria (`AC-1`…), constraints, design sources, decisions (links to ADRs), open questions marked `(blocking)` or `(non-blocking)`. Glossary terms marked `[[term]]` |
| `adr/YYYY-MM-DD-<slug>.md` | Dated | `Date:`, `Status:` proposed, accepted or superseded, `Supersedes:`, Context, Decision, Alternatives, Consequences. Never edited after accept; a later ADR supersedes it ([docs-current-or-dated](../../rules/docs-current-or-dated.md)) |
| `glossary.md` | Current | term, definition, synonyms to avoid, source. Second table: terms the human uses differently than the code |
| `alignment.md` | Current | task restated in ≤ 5 lines, agreed, assumptions, open questions, `Aligned: yes\|no`, `Confirmed by:` |

## Steps

1. **Restate and assess.** Restate task in ≤ 5 lines. Run `scripts/assess.sh` on it. Report size, vagueness, UI in one line
2. **Find and read related docs.** `scripts/find-related-docs.sh <topic words>`. Read every hit before asking anything
   - Link prior specs, ADRs, glossaries; never copy them
   - Hit looks stale or contradicts another → stop and ask which holds
   - Superseded or stale ADR stays; write an ADR that supersedes it
3. **Ask in batches.** `AskUserQuestion` when available, else numbered list
   - ≤ 4 questions per round, one decision each
   - Each carries a recommended default and one reason; free text always allowed
   - Never ask what a related doc already answers; cite it
   - `ui` true: run fidelity check in [figma-fidelity](references/figma-fidelity.md); fill spec's Design sources table
4. **Write incrementally.** After each round scaffold with `scripts/new-doc.sh spec|adr|glossary|alignment <topic> [--slug S]`, then fill. Keep spec and glossary in sync: every `[[term]]` in spec has a glossary row. One ADR per decision with real alternatives
5. **Read back.** Summarize in ≤ 10 lines: task, agreed, assumptions, open questions. Ask for explicit yes
   - Yes → `Aligned: yes`, `Confirmed by:` the role or name the human gives
   - Anything else → `Aligned: no`, loop to step 3
6. **Validate and hand off.** `scripts/check-align.sh <topic dir>` exits 0. Docs never committed. `write-plan` folds them into the plan once (goal, users, terms, decisions with rejected alternatives, acceptance criteria, open questions). No separate spec, ADR, or glossary file ships. DRY: plan is the only copy

## Rules

- Don't invent facts. Label each assumption `Assumption:`; keep out of Agreed until human confirms
- Two docs disagree → stop and ask. Never pick one silently
- `Aligned: yes` needs human's explicit yes in this conversation and no open `(blocking)` question
- Current docs describe today; decisions go in ADRs
- Chain stops after this phase until `Aligned: yes`

## Scripts

Each prints JSON, has `--help`. Exit 0 ok, 1 check failed, 2 usage, 3 precondition.

| Script | Use |
|---|---|
| `scripts/assess.sh [--file F \| TEXT…]` | `{size, vagueness, ui, suggest_align, reasons[]}` from fixed heuristics |
| `scripts/find-related-docs.sh <words…> [--root DIR]` | Ranked `{path, kind, score, title, date?}`, ≤ 15 |
| `scripts/new-doc.sh <kind> <topic> [--slug S]` | Scaffold from `assets/templates`; never overwrites |
| `scripts/check-align.sh [DIR]` | Structure, numbering, ADR fields, links, glossary terms, aligned state |

## Related

- [`write-plan`](../write-plan/write-plan.md) suggests this skill and reads `spec.md`
- [`plan-implement-review-watch`](../plan-implement-review-watch/plan-implement-review-watch.md) runs it as phase A0 (`apirw`)
- [glossary-overloaded-terms](../../rules/glossary-overloaded-terms.md) for terms that mean two things
