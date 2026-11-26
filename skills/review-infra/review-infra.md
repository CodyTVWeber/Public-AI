---
name: review-infra
description: Review build, deploy, and runtime config changes: CI, containers, IaC, environment, flags. Use when review's stages.sh turns it on, or alone for "review the pipeline/deploy change".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-infra

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Safe defaults; values differ per environment where they must; nothing production-only hardcoded
- Secrets come from the secret store, never files or images
- Rollout and rollback path is stated; a new flag defaults off and has an owner and removal point
- Resource limits, health checks, timeouts, and permissions are least-privilege
- A pipeline change cannot skip the repo's checks

## Not here

Application logic (review-logic), packages (review-dependencies).
