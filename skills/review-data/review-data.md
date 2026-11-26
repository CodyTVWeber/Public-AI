---
name: review-data
description: Review a diff that touches schema, migrations, models, or queries: reversibility, locking, backfill, integrity, data loss. Use when review's stages.sh turns it on, or alone for "review the migration".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-data

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Migration is reversible, or expand then contract; the destructive step is its own change
- Locks and runtime on large tables; backfill batched; safe to re-run
- Nullability, defaults, constraints, and indexes match how the data is read and written
- Transactions cover the writes that must succeed together; queries are parameterized
- Rollback of the code leaves the data readable; no data loss on revert
- Personal or sensitive columns are named, protected, and have retention covered

## Not here

Query speed at scale (review-concurrency for N+1 and unbounded reads).
