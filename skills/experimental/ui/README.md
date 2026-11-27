# UI skills

Screens a person can finish, that look considered.

| Skill | Does |
|---|---|
| [ui](ui.md) | Order of work, the screen note, sources |
| [ui-interaction](../ui-interaction/ui-interaction.md) | Job, action, feedback, errors, states, access |
| [ui-craft](../ui-craft/ui-craft.md) | Hierarchy, space, color, motion |

[write-plan](../../write-plan/write-plan.md) names the job and the states. [implement](../../implement/implement.md) builds to this bar. [review-ui](../../review-ui/review-ui.md) checks the diff.

These three live under [experimental](../README.md). They are not in the core or support set.

## Install

```bash
ln -sfn <path-to-this-repo>/skills/experimental/ui ~/.agents/skills/ui
ln -sfn <path-to-this-repo>/skills/experimental/ui-interaction ~/.agents/skills/ui-interaction
ln -sfn <path-to-this-repo>/skills/experimental/ui-craft ~/.agents/skills/ui-craft
```

## Invoke

- `/ui`
- "Make this screen beautiful"
- "This flow is hard to use"

## Files

| File | Role |
|---|---|
| `ui.md` (`SKILL.md` links to it) | Agent instructions |
| `../ui-interaction/ui-interaction.md` | Interaction bar |
| `../ui-craft/ui-craft.md` | Craft and motion bar |
