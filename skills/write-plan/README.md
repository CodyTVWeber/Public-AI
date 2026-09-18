# write-plan

AI-agnostic skill: write a dated plan markdown file, commit, push, and **ensure a PR exists** (create only if none already for that branch).

Used standalone or as **Phase A** of [plan-implement-review](../plan-implement-review/).

**Always starts from fresh latest `origin/main`** — never writes a plan on top of a feature branch. See §0 in `write-plan.md`.

## Install

### Grok

```bash
# Prefer symlink so AI repo edits are live:
ln -sfn /Users/user/code/AI/skills/write-plan ~/.grok/skills/write-plan
# SKILL.md already → write-plan.md inside that dir
```

### Claude Code

```bash
cp /Users/user/code/AI/skills/write-plan/write-plan.md ~/.claude/commands/write-plan.md
```

## Invoke

- `/write-plan`
- “Write a plan for …”
- Automatically as plan-builder inside `/plan-implement-review`
