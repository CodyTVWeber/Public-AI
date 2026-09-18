# explain-code

A Claude Code skill that turns a hard-to-hold-in-your-head bug (a race condition, a stale-snapshot
rollback, a cache clobber, an ordering bug) into a self-contained, animated HTML that shows the
before/after behavior side by side, instead of just describing it in prose.

## What it does

- Verifies the bug/fix against the real source before writing anything
- Pins every number in the visualization to something checkable in the code (no dramatized counts)
- Builds a two-panel animated simulation (buggy vs. fixed) with a scrolling event log and the real
  code diff underneath
- Traces the generated JS by hand (and recommends independent verification) before calling it done

## Setup

```bash
cp explain-code.md ~/.claude/commands/explain-code.md
```

## Usage

```
/explain-code <path to plan/investigation doc, or describe the bug>
```

Claude will re-verify the diagnosis against the real code, pick real numbers/constants for the
scenario, fill in `templates/explainer.html`, write a narrative matching the real execution order,
and save the result next to the plan doc it illustrates.

## Why this exists

Built out of a real incident: an optimistic-cache rollback bug in a React Query app where a
wholesale `onError` rollback was clobbering sibling mutations' successful writes. A plain-text
explanation of "onMutate snapshots the whole array, onError replaces the whole array" didn't land —
seeing it animate, side by side with the fix, did. Two things nearly undermined it and are now
built into the process as explicit steps:

1. The first draft dramatized the scenario ("10-15 tasks") instead of checking the real limit
   (`BUCKET_LIMIT = 3` in that codebase) — the visualization overstated the bug's real-world blast
   radius until corrected.
2. The first draft had a silent JS bug (a DOM id prefix mismatch) that killed the animation on the
   very first status update, with no visible error — it looked stuck, not broken, until manually
   traced.

Both are called out explicitly in `explain-code.md` as verification steps, not just as things that
happened once.

## Templates

[`templates/explainer.html`](templates/explainer.html) — the two-panel animated scaffold: item
list, event log, summary line, and a real code-diff section. Placeholder-driven
(`{{TITLE}}`, `{{BEFORE_DESC}}`, etc.) plus a `runAnimation()` stub to fill in with the real
narrative.

## Example

[`example/task-rollback-storm.html`](example/task-rollback-storm.html) — the worked example that
prompted this skill: a bucket-submit rollback bug in a task-management PWA, showing 3 concurrent
task completions (the app's actual `BUCKET_LIMIT`), one failing after the other two already
succeeded, with the wholesale-rollback bug wiping the successful ones on the left and the scoped
fix preserving them on the right. Open it directly in a browser — no build step, no dependencies.
