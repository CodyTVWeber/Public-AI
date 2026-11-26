---
name: review-data
description: Review a diff that touches schema, migrations, models, or queries: reversibility, locking, backfill, integrity, data loss. Use when review's stages.sh turns it on, or alone for "review the migration".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-data

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Migration reversible, or expand then contract. Destructive step = its own change
- Locks and runtime on large tables. Backfill batched and safe to re-run
- Nullability, defaults, constraints, indexes match read and write patterns
- Transactions cover writes that must succeed together. Queries parameterized
- Code rollback leaves data readable. No data loss on revert
- Personal or sensitive columns named, protected, retention covered

## Not here

Query speed at scale → review-concurrency (N+1, unbounded reads).
