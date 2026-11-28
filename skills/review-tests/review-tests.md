---
name: review-tests
description: Review the tests of a diff: coverage of changed behavior, assertion quality, and tests that pin nothing. Use when review's stages.sh turns it on (code or tests changed), or alone for "review the tests".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-tests

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Each changed behavior has a test. Code changed with no test files = bug unless plan says why
- Load `tdd` when that skill is installed. A test on a private collaborator, or an expected value copied from the implementation, is a bug
- Assert what happens, not that code ran. Whole-object assertions over field-by-field
- No test for a case that cannot occur (removed feature, impossible state). Removing a feature deletes its tests
- Unhappy paths named by review-non-happy-logic covered
- Styling-only change: snapshot diffs are class-string or structure only
- Deterministic: no sleeps, real clocks, network, ordering luck. Small factories over shared god setup

## Not here

Production logic → review-logic.
