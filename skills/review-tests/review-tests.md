---
name: review-tests
description: Review the tests of a diff: coverage of changed behavior, assertion quality, and tests that pin nothing. Use when review's stages.sh turns it on (code or tests changed), or alone for "review the tests".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-tests

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Each changed behavior has a test; code changed with no test files is a bug unless the plan says why
- Tests assert what happens, not that code ran; whole-object assertions over field-by-field
- No test for a case that cannot occur (removed feature, impossible state); removing a feature deletes its tests
- Unhappy paths named by review-non-happy-logic are covered
- Styling-only change: snapshot diffs are class-string or structure only
- Tests are deterministic: no sleeps, real clocks, network, or ordering luck; small factories over shared god setup

## Not here

Production logic (review-logic).
