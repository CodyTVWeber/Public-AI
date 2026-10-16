# implement

AI-agnostic skill: implement from a plan (or ticket), lint/test, commit, push, and **ensure a PR exists** (create only if none already).

Sibling of [write-plan](../write-plan/). Used alone or as Phase B of [plan-implement-review](../plan-implement-review/).

If the work came from a **tracker task** (e.g. Asana), post one Implement rN comment — rules in [tracker-comments.md](../plan-implement-review/references/tracker-comments.md).

## Install

### Grok

```bash
ln -sfn /Users/user/code/AI/skills/implement ~/.grok/skills/implement
# SKILL.md → implement.md inside that dir
```

### Claude Code

```bash
cp /Users/user/code/AI/skills/implement/implement.md ~/.claude/commands/implement.md
# or symlink into a project .claude/skills/implement/SKILL.md
```

## Invoke

- `/implement`
- “Implement the plan at …”
- “Implement tracker task …”
- Automatically as implementer inside `/plan-implement-review`

## PR rule (same as write-plan)

Create a PR **only if** there is not already an open PR for this head branch / same ticket. Prefer **one PR** for plan + code.
