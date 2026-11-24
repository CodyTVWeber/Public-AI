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
| E Gate | `skills/plan-implement-review/scripts/regression-gate.sh` (`review` §4) | Orchestrator |
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

`plan` alone = `write-plan` (same as `phases=plan`).

Starting mid-chain needs that phase's input: implement needs a plan path, ticket or checklist; review needs a branch/PR (+ plan); watch needs a PR/MR number. Missing → ask once.

## 0. Setup

1. Parse args: `skills/plan-implement-review/scripts/pir-args.sh "<args>"` → JSON `{phases, ticket, no_plan, implementer, fix_comments, max_rounds, task}`. Exit 2 (unknown phase, non-contiguous run, bad value) → ask once. `ticket` null → plain branch names, commits `<type>: <desc>`; `implementer` null → cheap tier of the orchestrator's model family
2. Vague term in the task → one-line flag: what was said, what it could mean, which you assume
3. Repo location unknown → search by distinctive text; several clones → ask. Never `git worktree`: new isolated work = a fresh clone under a scratch workspace (`<workspace>/<topic>/<repo>`) when the repo forbids worktrees
4. State: `skills/plan-implement-review/scripts/pir-state.sh init --topic <topic> --max-rounds <n>` (exit 3 = exists → `get`). Keys in [plan-implement-review](../plan-implement-review/) Configuration; touch only via `get` / `set KEY=VALUE`
5. Mark proof early: any behavior, screen, backend, or database change → `verify-change` evidence is mandatory in B, C and F

## A. Plan

Run `write-plan`. `no-plan` → skip; put a 5-line inline checklist (scope, steps, out of scope, screens touched) in the implementer prompt. Synthesis and judgment belong to the planner; the orchestrator only does mechanical grep.

**Check the plan before B.** Review compares code to the plan, so a wrong plan passes review. Before spawning the implementer, compare the plan with the user's own words and the ticket:

- Every user statement about the domain (what a term means, what is stored or sent) appears in the plan and nothing in it contradicts them
- Each overloaded term uses its glossary meaning ([glossary-overloaded-terms](../../rules/glossary-overloaded-terms.md))
- Any decision that changes what is stored, sent or returned is listed under **Needs your OK**

Mismatch, or anything under Needs your OK → stop and ask, even for local-only runs. Never settle it silently in the plan's rationale.

## B. Implement

Spawn a **background sub-agent** if the host supports it (cheap model, same effort for every resume); otherwise run the implement skill yourself in a separate pass. Prompt minimum: repo path, branch, plan path or checklist, "run `implement`", commit often, **do not push**, `verify-change` proof in the PR/MR, repo rules. Before each attempt `pir-state.sh inc-round` (exit 3 = rounds spent → hand off), then `set implementer_id=… subagent_id=…`. Wait on it; don't poll its transcript.

## C–E. Review loop

1. Run `review` on the branch; count blocking findings `k`
2. `skills/plan-implement-review/scripts/verdict.sh --round <r> --max <m> --blocking <k>` → `next`:
   - `gate` → `regression-gate.sh <repo> --base origin/<base>` (exit 3 = dirty tree), `pir-state.sh set regression_status=<status>`, then `verdict.sh --phase gate --regression <status> …` and follow its `next`
   - `done` → push (feature branch only) → draft PR/MR with the `verify-change` body (Build, Proof, Try it) → F
   - `fix` → write `review-roundN.md`, `inc-round`, resume the same implementer, back to 1
   - `hand_off` → stop; hand findings + `implementer_id` to the user
   - `wait` → implementer or gate not finished

Review owns the proof check: a change without the `verify-change` evidence for its kind (image, video, curl, query, diagram) is `fix required`.

## F. Watch

Interim note first (URL, gate result, evidence summary), then run `watch <n>` with `fix-comments`. Final report held until watch stops or hands off.

## Rules

- Max 3 implement rounds, enforced by `inc-round`; no automatic 4th. Watch has its own 2 fix rounds
- Never force-push, merge, approve or mark ready without being asked
- Remote branch rewritten under you → never overwrite (see `implement` §1)
- External posts carry an attribution prefix
- Report ≤ 8 lines per tick; details live in the PR/MR description

## Final report

Plan path (or "no plan") · PR/MR URL · implementer id · rounds used · verdict · regression status · evidence (count, uncaptured screens) · pipeline state · unresolved threads · fix rounds in watch.
