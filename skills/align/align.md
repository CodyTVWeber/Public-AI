---
name: align
description: Get the AI and the human to the same picture of a task or document before planning, by building a spec, ADRs, a glossary and a one-page alignment brief, reusing related docs. Use for "align on", /align, a large or vague task, a UI task with a design, or phase A0 of the plan-implement-review chain (apirw).
argument-hint: "<task or path to a document> [topic=<slug>]"
---

# Align

Close the gap between what the human means and what the AI heard, in writing, before `write-plan` runs. Docs only: no code changes, no branch, no PR.

## Outputs

Per topic dir, default `docs/align/<topic>/`. Working notes only: never committed. `scripts/new-doc.sh` detects the repo's doc layout (`docs/`, `doc/`, shared `docs/adr/` or `adr/`) and prints `convention`: tell the human which it chose.

| Doc | Kind | Holds |
|---|---|---|
| `spec.md` | Current | goal, users, scope, non-goals, numbered acceptance criteria (`AC-1`…), constraints, design sources, decisions (links to ADRs), open questions marked `(blocking)` or `(non-blocking)` |
| `adr/YYYY-MM-DD-<slug>.md` | Dated | `Date:`, `Status:` proposed, accepted or superseded, `Supersedes:`, Context, Decision, Alternatives, Consequences. Never edited after accept; a new ADR supersedes it ([docs-current-or-dated](../../rules/docs-current-or-dated.md)) |
| `glossary.md` | Current | term, definition, synonyms to avoid, source; a second table for terms the human uses differently than the code. Spec marks glossary terms as `[[term]]` |
| `alignment.md` | Current | task restated in at most 5 lines, agreed, assumptions, open questions, `Aligned: yes\|no`, `Confirmed by:` |

## Steps

1. **Restate and assess.** Restate the task in at most 5 lines. Run `scripts/assess.sh` on it. Report size, vagueness and UI in one line.
2. **Find and read related docs.** `scripts/find-related-docs.sh <topic words>`. Read every hit before asking anything.
   - Link prior specs, ADRs and glossaries; never copy them
   - A hit that looks stale or contradicts another: stop and ask which holds
   - A superseded or stale ADR stays; write a new ADR that supersedes it
3. **Ask in batches.** `AskUserQuestion` when available, else a numbered list.
   - At most 4 questions per round, one decision each
   - Each carries a recommended default and one reason; free text always allowed
   - Never ask what a related doc already answers; cite it instead
   - `ui` true: run the fidelity check in [figma-fidelity](references/figma-fidelity.md) and fill the spec's Design sources table
4. **Write incrementally.** After each round scaffold with `scripts/new-doc.sh spec|adr|glossary|alignment <topic> [--slug S]`, then fill. Keep spec and glossary in sync: every `[[term]]` in the spec has a glossary row. One ADR per decision that has real alternatives.
5. **Read back.** Summarize in at most 10 lines: task, agreed, assumptions, open questions. Ask for an explicit yes.
   - Yes: `Aligned: yes`, `Confirmed by:` the role or name the human gives
   - Anything else: `Aligned: no`, loop to step 3
6. **Validate and hand off.** `scripts/check-align.sh <topic dir>` exits 0. The docs are never committed. `write-plan` folds them into the plan once (goal, users, terms, decisions with rejected alternatives, acceptance criteria, open questions); no separate spec, ADR or glossary file ships. DRY: the plan is the only copy.

## Rules

- Do not invent facts. Label every assumption `Assumption:` and keep it out of Agreed until the human confirms it
- Two docs disagree: stop and ask; never pick one silently
- `Aligned: yes` needs the human's explicit yes in this conversation and no `(blocking)` question open
- Current docs describe today; decisions go in ADRs
- The chain stops after this phase until `Aligned: yes`

## Scripts

Each prints JSON and has `--help`. Exit 0 ok, 1 check failed, 2 usage, 3 precondition.

| Script | Use |
|---|---|
| `scripts/assess.sh [--file F \| TEXT…]` | `{size, vagueness, ui, suggest_align, reasons[]}` from fixed heuristics |
| `scripts/find-related-docs.sh <words…> [--root DIR]` | ranked `{path, kind, score, title, date?}`, at most 15 |
| `scripts/new-doc.sh <kind> <topic> [--slug S]` | scaffold from `assets/templates`; never overwrites |
| `scripts/check-align.sh [DIR]` | structure, numbering, ADR fields, links, glossary terms, aligned state |

## Related

- [`write-plan`](../write-plan/write-plan.md) suggests this skill and reads `spec.md`
- [`plan-implement-review-watch`](../plan-implement-review-watch/plan-implement-review-watch.md) runs it as phase A0 (`apirw`)
- [glossary-overloaded-terms](../../rules/glossary-overloaded-terms.md) for terms that mean two things
