---
name: review-dependencies
description: Review dependency changes in manifests and lockfiles: need, health, license, pinning, transitive impact. Use when review's stages.sh turns it on, or alone for "review the dependency bump".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-dependencies

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Each added or bumped package needed. Stdlib or existing dependency would not do
- Maintained, compatibly licensed, expected registry and name (typosquats)
- Pinned the way the repo pins. Lockfile matches manifest; no surprising transitive additions
- Bump with breaking changes ships the code changes it forces
- Dev-only packages stay out of runtime

## Not here

Usage in code → review-logic, review-security.
