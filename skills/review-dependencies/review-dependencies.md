---
name: review-dependencies
description: Review dependency changes in manifests and lockfiles: need, health, license, pinning, transitive impact. Use when review's stages.sh turns it on, or alone for "review the dependency bump".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-dependencies

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Each added or bumped package is needed; the standard library or an existing dependency would not do
- Maintained, licensed compatibly, and from the expected registry and name (typosquats)
- Pinned the way the repo pins; lockfile matches manifest and shows no surprising transitive additions
- A bump with breaking changes comes with the code changes it forces
- Dev-only packages stay out of runtime

## Not here

How the package is used in code (review-logic, review-security).
