---
name: review-concurrency
description: Review concurrency, caching, retry, and scale behavior of a diff: races, ordering, deadlocks, N+1, unbounded work. Use when review's stages.sh turns it on, or alone for "review thread safety/performance".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-concurrency

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Shared mutable state is guarded or removed; lock order is consistent; no blocking inside async paths
- Retries have limits, backoff, and idempotent targets; timeouts exist on every wait
- Queries and loops are bounded: no N+1, `select *` on wide tables, full scans, or unbounded lists
- Caches have an invalidation rule, a size bound, and a stale-read answer
- Background work and queues cope with duplicates, reordering, and shutdown

## Not here

Single-threaded correctness (review-logic), failure handling (review-non-happy-logic).
