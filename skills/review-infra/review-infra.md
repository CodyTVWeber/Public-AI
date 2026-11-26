---
name: review-infra
description: Review build, deploy, and runtime config changes: CI, containers, IaC, environment, flags. Use when review's stages.sh turns it on, or alone for "review the pipeline/deploy change".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-infra

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Safe defaults. Per-environment values where they must differ. Nothing production-only hardcoded
- Secrets from the secret store, never files or images
- Rollout and rollback path stated. Flag defaults off, has owner and removal point
- Resource limits, health checks, timeouts, permissions least-privilege
- Pipeline change cannot skip repo checks

## Not here

Application logic → review-logic. Packages → review-dependencies.
