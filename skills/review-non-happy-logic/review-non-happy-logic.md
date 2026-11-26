---
name: review-non-happy-logic
description: Review the unhappy paths of a diff: errors, bad input, nulls, empties, timeouts, partial failure, retries, external-call failure. Use when review's stages.sh turns it on, or alone for "what if it fails".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-non-happy-logic

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Every new external call (HTTP, DB, queue, file, process) has a failure path: timeout, retry limit, and a defined result
- Boundary inputs: null, empty, zero, negative, max size, wrong type, duplicate, unicode
- Errors are handled once, at the right layer, with context; no swallowed catch, no log-and-throw pairs
- Partial failure leaves consistent state: transactions, idempotency, cleanup on early return
- Error messages and status codes are specific and leak nothing sensitive
- Each unhappy path found here has a test (review-tests checks they exist)

## Not here

Main-path logic (review-logic), threading (review-concurrency).
