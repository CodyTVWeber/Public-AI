---
name: verify-change
description: Assemble proof on the PR from pyramid tests and plan-folder scripts already written. Use when opening or updating a PR/MR, when the user says verify, /verify, /verify-change, or as the verify phase of plan-implement-review-watch (after review, before watch).
argument-hint: "[PR/MR number or branch] [plan path]"
---

# Verify the change

Own stage after review, before watch. Letters: P, I, R, **V**, W (PIRVW; APIRVW when align is on). Not a review stage. The PR description is the proof.

Plan and align already named the observables ([pyramid](references/pyramid.md)). ATDD and script implementers already wrote the top-of-pyramid tests and the plan-folder recipe. This stage runs that work, adds only extra checks that are still useful, and puts evidence on the PR. It does not write the tests or the recipe.

The reviewer's job is to look at that evidence and say yes.

## Completion

Done when all of these hold:

- `check-pyramid.sh <plan>` exits 0 (skip line when there is no runtime behavior)
- Writer=`atdd` rows pass (the commands or files the plan names)
- Plan-folder `*.sh` ran; stdout on the PR (omit the folder when kinds is empty)
- Extra manual checks only for gaps those rows do not cover
- The PR body leads with **Proof**: UI screenshots or video, or the script/query/command/test output that proves a non-UI change
- **Try it** is one or two lines that point at the scenario (run this script; go to this URL and click these buttons). It does not walk through the scenario
- `check-pr-body.sh`, `proof-check.sh` (with `kinds.json` when present), `check-evidence-dir.sh` when the folder exists, `evidence-check.sh` for media all pass
- Docs-only: **no behavior change** line, no invented screenshots or scripts

Who may merge: merge policy (`skills/ai-risk/rules/merge-policy.md`). Proof does not change it.

## Assemble, do not author

1. `scripts/check-pyramid.sh <plan.md>`
2. Run each Writer=`atdd` row
3. Run each plan-folder `*.sh`; copy tiny stdout into `out/`
4. Capture extra UI or video only when a plan observable has no passing test or script
5. Fill `assets/pr-body.md` from that evidence

Missing tests or scripts → not this stage's job to write them. Send a verify-round to the matching implementer. Fill `kinds.json` only so the PR can show the miss.

Standalone `/verify` with no prior atdd/script implementers: run what exists; still do not invent a pyramid the plan never named.

## Kinds

Use `kinds.json` already in the plan folder. Menu: [kinds](references/kinds.md). Empty `kinds: []` means no product evidence. `diff-scope.sh` is a hint when the file is missing.

## No product evidence

Docs, comments, rules text, renames, formatting, or any diff with no runtime behavior: skip line in **Verification**, `kinds: []` and a `reason`. Do not invent screenshots, videos, curls, queries, or scripts.

On the PR: Build, Review guide, and a **no behavior change** line. The Proof table may be one row that says that. Skip Try it commands that do not exist.

Skip plan-folder scripts. `kinds.json` plus `evidence.md` (index only) are enough if the folder exists. Omit the folder when there is no recipe to keep.

## Plan folder

`scripts/plan-dir.sh <plan.md>` → `{plan, stem, dir}`. `dir` is the sibling folder named like the plan file (no `.md`). Script implementers commit the recipe there during implement. This stage runs it.

| File | Holds |
| --- | --- |
| `kinds.json` | `{kinds, reason}` |
| `*.sh` | The recipe a reviewer re-runs |
| `*.sql` | Read-only queries when kind `query` is picked and no script already runs them |
| `evidence.md` | Claims, commands, PR URL, links into the description. Tiny text snippets only |
| `out/*` | Script and pyramid-test stdout when it fits the size cap |

Never commit images, video, or other binaries. Those go on the PR. `check-evidence-dir.sh <dir>` fails binaries and files over 32KiB. `--allow-pending` before the PR exists. Exit 1 prints `missing[]`.

## PR description

Fill `assets/pr-body.md`. Stay lean. The body makes saying yes a breeze: show the evidence, point at how to re-run, stop.

1. **What changed.** One or two sentences. Link the task; do not retell it
2. **Proof.** UI: screenshots or video first. Non-UI: the output that proves it (pyramid test, script stdout, query result). One table row per claim
3. **Try it.** One or two lines. Point at the scenario; do not dump the steps. Simple UI: "go to this URL and click these buttons." Then Risk, Review guide, Build

Before opening or updating the PR: `scripts/check-pr-body.sh <body-file>`

Match proof to the solution. Use the kinds already picked. A still image does not cover a click, type, motion, or sequence. A backend or database change a person reaches through the product also uses that screen's video.

## Capture

- Media stays out of git. Attach to the PR so the forge hosts it. GitLab: `skills/implement/scripts/upload-evidence.mjs`
- Run `skills/implement/scripts/evidence-check.sh <files> --before <b> --after <a>` first. Exit 1 = failed capture
- Open every image and play every video. Blank frame, error page, or login wall = capture again
- Before = checkout of the base branch, built on its own. Not this branch
- Fake or local data only. No production rows, secrets, or real personal data
- Text that fits the plan-folder cap may be copied next to the plan so the plan still points at what passed
- App cannot run here: say so in the PR and still leave Try it

## Not ready

`skills/implement/scripts/proof-check.sh <body-file> <scope.json>` (put `kinds` from `kinds.json` into scope when present). Exit 1 lists `missing[]`. Then `check-evidence-dir.sh` and `check-pyramid.sh`. Then:

- A claim with no proof row
- Still image standing in for a behavior
- Try it that walks through the scenario instead of pointing at it
- Proof showing a failure: fix the product, capture again
- Top-of-pyramid tests or scripts missing: resume the atdd or script implementer, not this stage

By-eye checks live in [`review-proof`](../review-proof/review-proof.md). That skill is this phase's check, not a review stage.

## Chain

`pir-args` inserts `verify` after `review` when the run implements or watches (PIRV / PIRVW). Product wrong → orchestrator may run up to 3 more implement → review → verify cycles (`inc-verify-round`, separate from the original 3). Thin description stays in this phase. Missing recipe → resume the script or atdd implementer. `pi` / `implement-only`: implement still proves. Standalone: `/verify` or `phases=verify`. Review-only does not insert verify.

## Scripts

| Script | Use |
| --- | --- |
| `scripts/check-pyramid.sh <plan>` | Plan Verification section: layers, cases, caps, AC coverage |
| `scripts/check-pr-body.sh <body>` | Headers, tier, review guide, Try it cap, placeholders |
| `scripts/plan-dir.sh <plan.md>` | Sibling folder path |
| `scripts/check-evidence-dir.sh <dir>` | Recipe gate: kinds, scripts, size, no binaries |
| `../implement/scripts/proof-check.sh` | Body vs picked kinds |
| `../implement/scripts/evidence-check.sh` | Media files on disk |
