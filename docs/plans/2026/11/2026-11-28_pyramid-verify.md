# TDD-style plan-phase verification pyramid

Date: 2026-11-28
**Branch:** `cursor/pyramid-verify-abb9`
**Status:** draft

## Context

Scan of this public repo (`CodyTVWeber/Public-AI`; owner GitHub search, then this checkout). No other owner repo held a pyramid-verification skill. What is already here:

| Piece | Job |
|---|---|
| [`verify-change`](../../../skills/verify-change/verify-change.md) | Own PIRVW stage after review; PR body is the proof |
| [`write-plan`](../../../skills/write-plan/write-plan.md) | Durable plan; optional "Manual verification / test checklist" |
| [`align`](../../../skills/align/align.md) | Spec with numbered AC; no pyramid |
| PIR Phase B | One feature implementer |

Read from: `origin/main` `5c48699` (verify-phase merge).

Align: skipped (`assess.sh` size small). No runtime change: monitoring skipped.

## Why this approach

Plan and align name the middle and top of the testing pyramid (API-level and system/REST-level). Those rows are observables the human agreed: "user clicks Save and the row appears", "POST /items creates an item". Implementation under them may change; the rows should not. Unit tests stay with the feature implementer.

Separate test implementers write those tests. Script implementers write plan-folder recipes in parallel with feature. Verify runs that work, adds only extra checks that are still useful, and puts evidence on the PR. It does not write the tests or the recipe.

`check-pyramid.sh` is the skeleton for the table shape (layers, cases, caps, AC coverage). Skills are the muscles.

## Concrete steps

1. `check-pyramid.sh` + tests: system/api only, happy+critical, caps 4/8/6, skip line, no unit layer
2. Align spec template + `check-align.sh` heading + fixture; write-plan §1b required Verification section
3. PIR: spawn test, script, and feature roles; `pir-state` keys for test/script ids; CLI fallback stays feature-only
4. `implement` role table; verify-change assemble-not-author; review-proof runs `check-pyramid.sh`
5. AGENTS.md table row; write-plan README pointer

## Risks

- Three agents on overlapping test paths → planner must name disjoint globs; overlap sequences them
- Feature round pool must not burn on test/script launches (`inc-round` stays feature-only)
- Standalone `/implement` still covers every role the plan names so a run without PIR does not skip tests

## Verification

No runtime change: pyramid skipped.

## Out of scope

- Moving `evidence-check.sh` / `upload-evidence.mjs` out of `skills/implement/scripts/`
- Teaching `run-implementer.sh` the test and script roles
- Changing product test runners in downstream repos
