# Small MRs

One reviewable concern per MR. Small changes get faster, more careful reviews, merge with fewer conflicts, and revert cheaply. Industry guidance: ~100-200 changed lines is easy to review well; quality drops past ~400; ~1000 is too large to review.

## Budget (changed lines, excluding lockfiles, generated code, snapshots)

| Size | Action |
|---|---|
| ≤ 200 | Ideal |
| 201-400 | Fine |
| 401-800 | Warn: say why it can't split, or split |
| > 800 | Blocked on push / MR creation when the hard-limit count exceeds 800, until split (or override with stated reason). Low-risk repo: advisory |

Env-tunable: `MR_SIZE_SOFT` (warn), `MR_SIZE_HARD` (block).

The warning counts every changed line in that budget. The hard block leaves out documentation and repo-support files: Markdown and other docs (`*.md`, `*.mdx`, `*.rst`, `*.adoc`, paths under `docs/`, `doc/`, or `documentation/`); AI setup (`.claude/`, `.cursor/`, `.cursorrules`); lint and guard scripts (`scripts/lint/`, `scripts/clean-code/`, `scripts/guard/`, `.githooks/`, `.husky/`, lint or format config, and a script whose name contains `lint`).

## Low-risk repos

- Qualifies: ships nothing that runs for users (no deployed app, service, job, or data). E.g. docs, AI config/skills/rules, personal tooling
- Never qualifies: deployed code, shared libraries, infra
- Declare: tracked `.mr-size` at repo root, line `risk: low`
- Effect: > 800 block → advisory line `low-risk repo (.mr-size): size is advisory`, exit 0
- Split advice unchanged. One concern per commit still applies

## How to keep it small

- One concern: refactor, behavior change, dependency bump, generated output, and docs are separate MRs
- Mechanical changes (renames, formatting, moves, regenerated clients) go alone so reviewers can skim
- Ship preparatory refactor first, then the feature that gets small because of it
- Slice vertically (thin end-to-end path) or along natural seams: schema vs code using it, backend vs frontend, library vs call sites
- Stack dependent MRs; each targets the one below; merges flow upward (merge, don't rebase shared branches)
- Hide unfinished work behind a flag instead of a long-lived branch
- Open a draft early. Large unfinished branch = signal to cut the next slice now
- Tests and the code they cover ship together, same MR, even if it grows slightly
- One logical change per commit, message says why. Reviewers go commit by commit. Moves and renames get own commit
- Review own diff before asking. Comment inline on any hunk whose reason isn't obvious

## Order a stack by risk: safest first, riskiest last

A stack merges bottom to top. Put the most failure-prone work at the end. If something fails in review, CI, or production, everything below has already landed and proven itself; only the last piece is blocked or reverted.

| Position | What goes there | Typical examples |
|---|---|---|
| Bottom (merge first) | Reversible, mechanical, behavior-neutral | Tests, docs, renames, formatting, pure refactors, unused code, dependency bumps with no API change |
| Middle | Behavior added but inert or guarded | Code behind off flag, additive schema changes, endpoints with no callers |
| Top (merge last) | Hard to undo or user-visible | Flag flips, cutovers, behavior changes, auth, payments or data handling, destructive migrations, deleting the replaced path, infra and deploy config |

- **Expand, migrate, contract:** add the replacement path first, move callers next, remove the replaced path last. Destructive step is always the final MR
- **Activation is its own MR:** keep the switch (flag default, route, config) separate from code it turns on. Riskiest moment = one small, revertable diff
- **Dependencies fight the order:** if lower MRs need a risky change, cut it as thin as possible, land behind interface or flag, keep rest above or beside it. Don't let a large risky MR sit at bottom
- **Label each MR** in stack table with risk (low / medium / high) and how to revert
- **Don't mix tiers:** refactor riding in a high-risk MR hides in the risk. Move it down the stack
- **Revert plan:** reverting top MR must leave lower ones working. Check before merging top

## Before opening an MR

1. Run `scripts/clean-code/check-mr-size.sh`
2. Over budget: list concerns in diff, cut along those lines, open first slice
3. Description states what changed, scope or risk, and anything reviewer must run or check

## Overriding

`CLEAN_CODE_SKIP=1` for one command; state why in MR description. For cases like a single large rename, vendored drop, or unsplittable migration. Never for convenience.
