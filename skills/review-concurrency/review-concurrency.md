---
name: review-concurrency
description: Review concurrency, caching, retry, and scale behavior of a diff: races, ordering, deadlocks, N+1, unbounded work. Use when review's stages.sh turns it on, or alone for "review thread safety/performance".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-concurrency

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Shared mutable state guarded or removed. Lock order consistent. No blocking inside async paths
- Retries: limits, backoff, idempotent targets. Timeouts on every wait
- Queries and loops bounded: no N+1, `select *` on wide tables, full scans, unbounded lists
- Caches: invalidation rule, size bound, stale-read answer
- Background work and queues handle duplicates, reordering, shutdown

## Not here

Single-threaded correctness → review-logic. Failure handling → review-non-happy-logic.
