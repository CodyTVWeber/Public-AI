# outline-output

Nested-outline output shape for all agent output: chat, drafts, PR descriptions. Word economy, plain voice, rejected patterns, handoff rules, and a self-check backed by [email-style](../email-style/)'s lint.

## Install

### Claude Code

```bash
cp <path-to-this-repo>/skills/outline-output/outline-output.md ~/.claude/commands/outline-output.md
```

### Other agents

```bash
ln -sfn <path-to-this-repo>/skills/outline-output ~/.agents/skills/outline-output
```

## Invoke

- `/outline-output`
- "Keep it scannable"

## Lint

```bash
node skills/email-style/scripts/draft-lint.mjs FILE --profile output
```

Checks banned phrases, emoji, time-zone labels, opening length. Exit 0 clean, 1 violations, 2 usage; install `email-style` alongside.
