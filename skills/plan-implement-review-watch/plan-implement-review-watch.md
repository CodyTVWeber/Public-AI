---
name: plan-implement-review-watch
description: Run the full chain [align →] plan → implement → review → watch [→ monitor] as separate skills, with a capped fix loop, verify-change proof in the PR/MR, a final watch, and an optional post-deploy monitor. Use for "plan implement review watch", /plan-implement-review-watch, /pirw, /apirw to start with align, or /apirwm to end with monitor.
argument-hint: "<task> [phases=align,plan,implement,review,watch,monitor] [ticket=X] [no-plan] [implementer=<cheap model>] [fix-comments=yes] [max-rounds=3] [window=1h] [cadence=10m]"
---

# Plan → Implement → Review → Watch

Orchestrator drives. Each phase = own skill, run in order. Extends [plan-implement-review](../plan-implement-review/) with watch phase and [`verify-change`](../verify-change/verify-change.md) proof in PR/MR.

| Phase | Skill | Who runs it |
|---|---|---|
| A0 Align | `align` | Orchestrator, interactive |
| A Plan | `write-plan` (alias `plan`) | Orchestrator |
| B Implement | `implement` | Background implementer agent (cheap model) |
| C Review | `review` | Orchestrator (read-only) |
| D Fix | `implement` again | Same implementer, resumed with `review-roundN.md` |
| E Gate | `skills/plan-implement-review/scripts/regression-gate.sh` (`review` §4) | Orchestrator |
| F Watch | `watch` | Orchestrator, self-paced |
| G Monitor | `monitor` | Orchestrator, self-paced, read-only, starts after change deployed to PROD |

## Phases and aliases

`phases=` picks contiguous run of the six skills. Default `plan` through `watch`. `align` and `monitor` only when asked. Aliases only set it:

| Phases | Short | Long |
|---|---|---|
| plan → implement | `pi` | `plan-implement` |
| implement → review | `ir` | `implement-review` |
| review → watch | `rw` | `review-watch` |
| plan → implement → review | `pir` | `plan-implement-review` |
| implement → review → watch | `irw` | `implement-review-watch` |
| plan → implement → review → watch | `pirw` | `plan-implement-review-watch` |
| align → plan → implement → review → watch | `apirw` | — |
| align → plan → implement → review → watch → monitor | `apirwm` | — |
| monitor | `m` | — |

`plan` alone = `write-plan` (same as `phases=plan`). Other runs via `phases=`, e.g. `phases=align,plan`, `phases=align`, `phases=watch,monitor`.

Starting mid-chain needs that phase's input. Missing → ask once.
- align: task or document
- implement: plan path, ticket, or checklist
- review: branch/PR (+ plan)
- watch: PR/MR number
- monitor: proof of PROD deploy + Monitoring plan or diff

## 0. Setup

1. Parse args: `skills/plan-implement-review/scripts/pir-args.sh "<args>"` → JSON `{phases, ticket, no_plan, implementer, fix_comments, max_rounds, window, cadence, task}`. Exit 2 (unknown phase, non-contiguous run, bad value) → ask once.
   - `ticket` null → plain branch names, commits `<type>: <desc>`.
   - `implementer` null → cheap tier of orchestrator's model family.
2. Vague term in task → one-line flag: what was said, what it could mean, which you assume.
3. Repo location unknown → search by distinctive text. Several clones → ask.
   - Isolated work = fresh clone under scratch workspace (`<workspace>/<topic>/<repo>`).
   - Worktrees only for parallel implement slices (implement §Parallel slices). Merged and removed before phase ends.
4. State: `skills/plan-implement-review/scripts/pir-state.sh init --topic <topic> --max-rounds <n>` (exit 3 = exists → `get`). Keys: [plan-implement-review](../plan-implement-review/) Configuration. Touch only via `get` / `set KEY=VALUE`.
5. Mark proof early: any behavior, screen, backend, or database change → `verify-change` evidence mandatory in B, C, F.

## A0. Align

Run `align`. Writes `docs/align/<topic>/`, ends with read-back. Chain stops until `alignment.md` says `Aligned: yes`. `Aligned: no` or blocking question → ask, don't plan. Pass topic dir to Plan as `align=<dir>`. Run alone (`phases=align`): report = doc paths + aligned state.

## A. Plan

Run `write-plan`. `no-plan` → skip; put 5-line inline checklist (scope, steps, out of scope, screens touched) in implementer prompt. Synthesis and judgment belong to planner; orchestrator only does mechanical grep.

**Check plan before B.** Review compares code to plan, so wrong plan passes review. Before spawning implementer, compare plan with user's own words and ticket:

- Every user statement about domain (what a term means, what is stored or sent) appears in plan. Nothing contradicts it.
- Each overloaded term uses glossary meaning ([glossary-overloaded-terms](../../rules/glossary-overloaded-terms.md)).
- Any decision changing what is stored, sent, or returned → listed under **Needs your OK**.

Mismatch, or anything under Needs your OK → stop, ask, even for local-only runs. Never settle silently in plan rationale.

## B. Implement

- Spawn **background sub-agent** if host supports it (cheap model, same effort every resume). Otherwise run implement skill yourself in separate pass.
- Prompt minimum: repo path, branch, plan path or checklist, "run `implement`", commit often, **do not push**, `verify-change` proof in PR/MR, repo rules.
- Before each attempt: `pir-state.sh inc-round` (exit 3 = rounds spent → hand off), then `set implementer_id=… subagent_id=…`.
- Wait on it. Don't poll its transcript.

Parallel slices follow implement §Parallel slices. Orchestrator owns merging and cleanup. Evidence and regression gate run once on integrated branch.

## C–E. Review loop

1. Run `review` on branch. Count blocking findings `k`.
2. `skills/plan-implement-review/scripts/verdict.sh --round <r> --max <m> --blocking <k>` → `next`:
   - `gate` → `regression-gate.sh <repo> --base origin/<base>` (exit 3 = dirty tree). `pir-state.sh set regression_status=<status>`. Then `verdict.sh --phase gate --regression <status> …` and follow its `next`.
   - `done` → push (feature branch only) → draft PR/MR with `verify-change` body (Build, Proof, Try it) → F.
   - `fix` → write `review-roundN.md`, `inc-round`, resume same implementer, back to 1.
   - `hand_off` → stop. Hand findings + `implementer_id` to user.
   - `wait` → implementer or gate not finished.

Review owns proof check: change without `verify-change` evidence for its kind (image, video, curl, query, diagram) = `fix required`.

## F. Watch

Interim note first (URL, gate result, evidence summary). Then run `watch <n>` with `fix-comments`. Final report held until last phase run stops or hands off.

## G. Monitor

Run `monitor` with `window=` (default `1h`) and `cadence=` (default `10m`).

- Input: plan's Monitoring plan, else one built from diff ([write-plan](../write-plan/write-plan.md) §1).
- Starts only when watch reports merged **and** deployed to PROD, with proof (deploy link or served version). Otherwise one line naming what's missing. Resume with `phases=monitor`.
- Read-only: observe and report, never act.
- `degraded` → stop, give evidence + recommended action, ask human.
- Final report line: monitor verdict · window · signals ok/warn/fail/unknown.

## Rules

- Max 3 implement rounds, enforced by `inc-round`. No automatic 4th. Watch has own 2 fix rounds.
- Never force-push, merge, approve, or mark ready without being asked.
- Remote branch rewritten under you → never overwrite (see `implement` §1).
- External posts carry attribution prefix.
- Report ≤ 8 lines per tick. Details live in PR/MR description.

## Final report

Plan path (or "no plan") · PR/MR URL · implementer id · rounds used · verdict · regression status · evidence (count, uncaptured screens) · pipeline state · unresolved threads · fix rounds in watch · monitor verdict (when run).
