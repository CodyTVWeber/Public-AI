---
name: verify-change
description: Prove a change works with evidence on the PR, and leave the recipe next to the plan. Use when opening or updating a PR/MR, when the user says verify, /verify, /verify-change, or as the verify phase of plan-implement-review-watch (after review, before watch).
argument-hint: "[PR/MR number or branch] [plan path]"
---

# Verify the change

Own stage after review, before watch. Letters: P, I, R, **V**, W (PIRVW; APIRVW when align is on). Not a review stage. The PR description is the proof. A sibling folder next to the plan holds the recipe (scripts) and a short index of links, not binaries.

The reviewer's job is to look at that evidence and say yes.

## Completion

Done when all of these hold:

- `kinds.json` is a pick (`[]` is the pick when there is no runtime behavior)
- The PR body leads with **Proof**: UI screenshots or video, or the script/query/command output that proves a non-UI change
- **Try it** is one or two lines that point at the scenario (run this script; go to this URL and click these buttons). It does not walk through the scenario
- `check-pr-body.sh`, `proof-check.sh` (with `kinds.json` when present), `check-evidence-dir.sh` when the folder exists, `evidence-check.sh` for media all pass
- Docs-only: **no behavior change** line, no invented screenshots or scripts

Who may merge: merge policy (`skills/ai-risk/rules/merge-policy.md`). Proof does not change it.

## Pick what proves this change

Path globs suggest. They do not require. Write `kinds.json` with the kinds that actually show this solution works, plus a one-line `reason`. Menu: [kinds](references/kinds.md). Empty `kinds: []` means no product evidence.

`skills/plan-implement-review/scripts/diff-scope.sh <base>` is a hint. Drop a suggested kind when the diff is not that behavior. Add a kind the globs missed. One script may cover several checks.

## No product evidence

Docs, comments, rules text, renames, formatting, or any diff with no runtime behavior: `kinds: []` and a `reason`. Do not invent screenshots, videos, curls, queries, or scripts.

On the PR: Build, Review guide, and a **no behavior change** line. The Proof table may be one row that says that. Skip Try it commands that do not exist.

Skip plan-folder scripts. `kinds.json` plus `evidence.md` (index only) are enough if the folder exists. Omit the folder when there is no recipe to keep.

## Plan folder

`skills/verify-change/scripts/plan-dir.sh <plan.md>` → `{plan, stem, dir}`. `dir` is the sibling folder named like the plan file (no `.md`).

Commit there:

| File | Holds |
| --- | --- |
| `kinds.json` | `{kinds, reason}` |
| `*.sh` | The recipe a reviewer re-runs |
| `*.sql` | Read-only queries when kind `query` is picked and no script already runs them |
| `evidence.md` | Claims, commands, PR URL, links into the description. Tiny text snippets only |
| `out/*` | Script stdout when it fits the size cap |

Never commit images, video, or other binaries. Those go on the PR. `check-evidence-dir.sh <dir>` fails binaries and files over 32KiB. `--allow-pending` before the PR exists. Exit 1 prints `missing[]`.

## PR description

Fill `assets/pr-body.md`. Stay lean. The body makes saying yes a breeze: show the evidence, point at how to re-run, stop.

1. **What changed.** One or two sentences. Link the task; do not retell it
2. **Proof.** UI: screenshots or video first. Non-UI: the output that proves it (script stdout, query result). One table row per claim
3. **Try it.** One or two lines. Point at the scenario; do not dump the steps. Simple UI: "go to this URL and click these buttons." Then Risk, Review guide, Build

Before opening or updating the PR: `skills/verify-change/scripts/check-pr-body.sh <body-file>`

Match proof to the solution. Use the kinds you picked. A still image does not cover a click, type, motion, or sequence. A backend or database change a person reaches through the product also uses that screen's video.

## Capture

- Media stays out of git. Attach to the PR so the forge hosts it. GitLab: `skills/implement/scripts/upload-evidence.mjs`
- Run `skills/implement/scripts/evidence-check.sh <files> --before <b> --after <a>` first. Exit 1 = failed capture
- Open every image and play every video. Blank frame, error page, or login wall = capture again
- Before = checkout of the base branch, built on its own. Not this branch
- Fake or local data only. No production rows, secrets, or real personal data
- Text that fits the plan-folder cap may be copied next to the plan so the plan still points at what passed
- App cannot run here: say so in the PR and still leave Try it

## Not ready

`skills/implement/scripts/proof-check.sh <body-file> <scope.json>` (put `kinds` from `kinds.json` into scope when present). Exit 1 lists `missing[]`. Then `check-evidence-dir.sh`. Then:

- A claim with no proof row
- Still image standing in for a behavior
- Try it that walks through the scenario instead of pointing at it
- Proof showing a failure: fix the product, capture again

By-eye checks live in [`review-proof`](../review-proof/review-proof.md). That skill is this phase's check, not a review stage.

## Chain

`pir-args` inserts `verify` after `review` when the run implements or watches (PIRV / PIRVW). After a fix round that already passed review, run this skill again. `pi` / `implement-only`: implement still proves. Standalone: `/verify` or `phases=verify`. Review-only does not insert verify.

## Scripts

| Script | Use |
| --- | --- |
| `scripts/check-pr-body.sh <body>` | Headers, tier, review guide, Try it cap, placeholders |
| `scripts/plan-dir.sh <plan.md>` | Sibling folder path |
| `scripts/check-evidence-dir.sh <dir>` | Recipe gate: kinds, scripts, size, no binaries |
| `../implement/scripts/proof-check.sh` | Body vs picked kinds |
| `../implement/scripts/evidence-check.sh` | Media files on disk |
