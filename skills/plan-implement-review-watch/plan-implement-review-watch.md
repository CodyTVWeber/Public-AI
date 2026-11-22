---
name: plan-implement-review-watch
description: Run the full chain plan → implement → review → watch as four separate skills, with a capped fix loop, verify-change proof in the PR/MR, and a final watch. Use for "plan implement review watch", /plan-implement-review-watch, or /pirw.
argument-hint: "<task> [phases=plan,implement,review,watch] [ticket=X] [no-plan] [implementer=<cheap model>] [fix-comments=yes] [max-rounds=3]"
---

# Plan → Implement → Review → Watch

Orchestrator drives; each phase is its own skill, run in order. Extends [plan-implement-review](../plan-implement-review/) with a watch phase and [`verify-change`](../verify-change/verify-change.md) proof in the PR/MR.

| Phase | Skill | Who runs it |
|---|---|---|
| A Plan | `write-plan` (alias `plan`) | Orchestrator |
| B Implement | `implement` | Background implementer agent (cheap model) |
| C Review | `review` | Orchestrator (read-only) |
| D Fix | `implement` again | Same implementer, resumed with `review-roundN.md` |
| E Gate | `review` §4 regression gate | Orchestrator |
| F Watch | `watch` | Orchestrator, self-paced |

## Phases and aliases

`phases=` picks a contiguous run of the four skills (default all). Aliases only set it:

| Phases | Short | Long |
|---|---|---|
| plan → implement | `pi` | `plan-implement` |
| implement → review | `ir` | `implement-review` |
| review → watch | `rw` | `review-watch` |
| plan → implement → review | `pir` | `plan-implement-review` |
| implement → review → watch | `irw` | `implement-review-watch` |
| all four | `pirw` | `plan-implement-review-watch` |

Starting mid-chain needs that phase's input: implement needs a plan path, ticket or checklist; review needs a branch/PR (+ plan); watch needs a PR/MR number. Missing → ask once.

## 0. Setup

1. Parse args: `ticket` (optional; none → plain branch names, commits `<type>: <desc>`), `no-plan`, `implementer` (default: the cheap tier of the orchestrator's model family), `fix-comments` (default no), `max-rounds` (default 3)
2. Vague term in the task → one-line flag: what was said, what it could mean, which you assume
3. Repo location unknown → search by distinctive text; several clones → ask. Never `git worktree`: new isolated work = a fresh clone under a scratch workspace (`<workspace>/<topic>/<repo>`) when the repo forbids worktrees
4. State file `/tmp/pir-<topic>/state.json`: topic, plan_path, branches, mr, implementer_id, round, max_rounds, regression_status
5. Mark proof early: any behavior, screen, backend, or database change → `verify-change` evidence is mandatory in B, C and F

## A. Plan

Run `write-plan`. `no-plan` → skip; put a 5-line inline checklist (scope, steps, out of scope, screens touched) in the implementer prompt. Synthesis and judgment belong to the planner; the orchestrator only does mechanical grep.

## B. Implement

Spawn a **background sub-agent** if the host supports it (cheap model, same effort for every resume); otherwise run the implement skill yourself in a separate pass. Prompt minimum: repo path, branch, plan path or checklist, "run `implement`", commit often, **do not push**, `verify-change` proof in the PR/MR, repo rules. Store `implementer_id`. Wait on it; don't poll its transcript.

## C–E. Review loop

1. Run `review` on the branch
2. approve → regression gate → push (feature branch only) → draft PR/MR with the `verify-change` body (Build, Proof, Try it) → F
3. fix required, `round < max-rounds` → write `review-roundN.md`, resume the same implementer, back to C
4. rounds spent → stop, hand findings + `implementer_id` to the user

Review owns the proof check: a change without the `verify-change` evidence for its kind (image, video, curl, query, diagram) is `fix required`.

## F. Watch

Interim note first (URL, gate result, evidence summary), then run `watch <n>` with `fix-comments`. Final report held until watch stops or hands off.

## Rules

- Max 3 implement rounds; no automatic 4th. Watch has its own 2 fix rounds
- Never force-push, merge, approve or mark ready without being asked
- Remote branch rewritten under you → never overwrite (see `implement` §1)
- External posts carry an attribution prefix
- Report ≤ 8 lines per tick; details live in the PR/MR description

## Final report

Plan path (or "no plan") · PR/MR URL · implementer id · rounds used · verdict · regression status · evidence (count, uncaptured screens) · pipeline state · unresolved threads · fix rounds in watch.
