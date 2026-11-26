---
name: review-non-happy-logic
description: Review the unhappy paths of a diff: errors, bad input, nulls, empties, timeouts, partial failure, retries, external-call failure. Use when review's stages.sh turns it on, or alone for "what if it fails".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-non-happy-logic

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Each added external call (HTTP, DB, queue, file, process) has a failure path: timeout, retry limit, defined result
- Boundary inputs: null, empty, zero, negative, max size, wrong type, duplicate, unicode
- Errors handled once, at the right layer, with context. No swallowed catch. No log-and-throw pairs
- Partial failure leaves consistent state: transactions, idempotency, cleanup on early return
- Error messages and status codes specific; leak nothing sensitive
- Each unhappy path has a test (review-tests checks existence)

## Not here

Main-path logic → review-logic. Threading → review-concurrency.
