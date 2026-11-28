---
name: tdd
description: Test-first behavior changes. A failing test first, one slice at a time, at seams the plan names. Use for TDD, red-green, test first, or when implement names this skill.
argument-hint: "[plan path or behavior]"
---

# Test first

A seam is the public boundary a test calls. Tests live at seams.

## Before the loop

1. Read the plan's acceptance criteria
2. List the seams. Each line: boundary, what a failing test catches, what it misses
3. Plan names seams → use those. Plan is silent → ask once, then use the public boundary the plan describes

## Loop

One slice: one failing test, the least code that passes, repeat.

| Rule | Do |
| --- | --- |
| Red first | The test fails for the reason the slice claims |
| One slice | No second test until this one passes |
| Independent expected value | A literal, a worked example, or the spec. Not a copy of the implementation |
| Public only | Call the seam. Do not assert a private function |

A rename that breaks a seam test means the test was on the wrong boundary.

## Where tests go

This pack: Bash under `scripts/tests/` or `skills/**/scripts/tests/`, Node `node --test` for `.test.mjs`. The host repo's runner wins when one exists.

Load [codebase-design](../codebase-design/SKILL.md) when the seam itself is the question.
