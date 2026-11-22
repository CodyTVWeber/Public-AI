# Small MRs

One reviewable concern per MR. Small changes get faster, more careful reviews, merge with fewer
conflicts, and are cheap to revert. Common industry guidance: roughly 100-200 changed lines is
easy to review well, review quality drops past ~400, and ~1000 is too large to review at all.

## Budget (changed lines, excluding lockfiles, generated code, snapshots)

| Size | Action |
|---|---|
| ≤ 200 | Ideal |
| 201-400 | Fine |
| 401-800 | Warn: say why it can't be split, or split it |
| > 800 | Blocked on push / MR creation until split (or override with a stated reason) |

Thresholds are env-tunable: `MR_SIZE_SOFT` (warn), `MR_SIZE_HARD` (block).

## How to keep it small

- One concern: refactor, behavior change, dependency bump, generated output and docs are
  separate MRs
- Mechanical changes (renames, formatting, moves, regenerated clients) go alone, so reviewers can
  skim them
- Ship the preparatory refactor first, then the feature that becomes small because of it
- Slice vertically (a thin end-to-end path) or along natural seams: schema vs code that uses it,
  backend vs frontend, library vs call sites
- Stack dependent MRs; each targets the one below it, and merges flow upward (merge, don't
  rebase shared branches)
- Hide unfinished work behind a flag instead of holding a long-lived branch
- Open a draft early; a large unfinished branch is the signal to cut the next slice now
- Tests and the code they cover ship together; keep them in the same MR even if it grows slightly
- One logical change per commit, with a message that says why, so reviewers can go commit by
  commit. Moves and renames get their own commit
- Review your own diff before asking: comment inline on any hunk whose reason is not obvious

## Order a stack by risk: safest first, riskiest last

A stack merges bottom to top, so put the work most likely to go wrong at the end. If something
fails in review, in CI, or in production, everything below it has already landed and proven
itself, and only the last piece is blocked or reverted.

| Position | What goes there | Typical examples |
|---|---|---|
| Bottom (merge first) | Reversible, mechanical, behavior-neutral | Tests, docs, renames, formatting, pure refactors, new unused code, dependency bumps with no API change |
| Middle | Behavior added but inert or guarded | Code behind a flag that is off, additive schema changes, new endpoints with no callers |
| Top (merge last) | Hard to undo or user-visible | Flag flips and cutovers, behavior changes, auth, payments or data handling, destructive migrations, deleting the old path, infrastructure and deploy config |

- **Expand, migrate, contract:** add the new path first, move callers next, remove the old path
  last. The destructive step is always the final MR
- **Activation is its own MR:** keep the switch (flag default, route, config) separate from the
  code it turns on, so the riskiest moment is one small, revertable diff
- **Dependencies fight the order:** if lower MRs need a risky change, cut that change as thin as
  possible, land it behind an interface or flag, and keep the rest of the work above or beside it
  rather than letting a large risky MR sit at the bottom
- **Label each MR** in the stack table with its risk (low / medium / high) and how to revert it
- **Do not mix tiers:** a refactor that rides along in a high-risk MR hides in the risk; move it
  down the stack
- **Revert plan:** reverting the top MR must leave the lower ones working; check that before
  merging the top one

## Before opening an MR

1. Run `scripts/clean-code/check-mr-size.sh`
2. Over budget: list the concerns in the diff, cut along those lines, open the first slice
3. Description states what changed, scope or risk, and anything the reviewer must run or check

## Overriding

Set `CLEAN_CODE_SKIP=1` for one command and state why in the MR description. Overrides are for
cases such as a single large rename, a vendored drop or an unsplittable migration, never for
convenience.
