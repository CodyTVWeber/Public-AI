## What changed

One or two sentences. Name the behavior a reviewer can observe. Link the task or issue for the why.

## Proof

UI: screenshots or a short video here first.

Non-UI: paste the script, query, or command output that proves it.

| Claim | Kind | Evidence |
| --- | --- | --- |
| `<what the reviewer can see>` | image, video, script, query, log, or — | `<the screenshot, video, or output>` |

Docs-only: one row, **no behavior change**, no media.

## Try it

1. `<run this script, or go to this URL, log in, and click these buttons>`

## Risk

`low`, `medium`, or `high`, with one line on why. Then: `Merge policy: <profile>` quoted from its source (`docs/rules/ai-merge-policy.md` or the org policy), and who must approve under it.

## Review guide

- **Size:** `<n>` changed lines in `<n>` files (generated and lock files excluded). `<n>` commits, one logical change each: read them in order
- **Start here:** `<file>`: the one file that explains the change
- **Look hard:** `<file:line>` `<why it is tricky or risky>` (list every hunk that deserves care)
- **Skim:** `<mechanical, generated, renamed or moved files>`
- **Not in this change:** `<what a reviewer might expect but is deliberately left out, and where it goes>`
- **Stack:** `<stands alone | depends on !nn | followed by !nn (the riskier one)>`
- **Decisions to check:** `<the one or two judgment calls where you want a second opinion>`

## Build

- Command: `<the project's check>`
- CI: `<link to this commit's run>`
- Result: `<one green line>`

## Rollback

How to undo: `revert this merge`, or the exact steps when it is not a clean revert (flag off, down migration, redeploy the previous build). For a high-tier change this section is required.
