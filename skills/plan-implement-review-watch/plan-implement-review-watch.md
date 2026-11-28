---
name: plan-implement-review-watch
description: Run the full chain [align →] plan → implement → review → verify → watch [→ monitor] as separate skills, with a capped fix loop, a distinct verify stage after review, a final watch, and an optional post-deploy monitor. Use for "plan implement review watch", /plan-implement-review-watch, /pirw or /pirvw, /apir to start with align and stop after verify, /apirw or /apirvw to start with align, or /apirwm to end with monitor.
argument-hint: "<task> [phases=align,plan,implement,review,verify,watch,monitor] [ticket=X] [no-plan] [implementer=<cheap model>] [fix-comments=yes] [max-rounds=3] [window=1h] [cadence=10m]"
---

# Plan → Implement → Review → Verify → Watch

Orchestrator drives. Each phase = own skill, run in order. Extends [plan-implement-review](../plan-implement-review/) with a [`verify-change`](../verify-change/verify-change.md) stage after review, then watch. Letters: P, I, R, V, W (PIRVW; APIRVW when align is on).

| Phase | Skill | Who runs it |
|---|---|---|
| A0 Align | `align` | Orchestrator, interactive |
| A Plan | `write-plan` (alias `plan`) | Orchestrator |
| B Implement | `implement` | Background implementer agent (cheap model) |
| C Review | `review` | Orchestrator (read-only) |
| D Fix | `implement` again | Same implementer, resumed with `review-roundN.md` |
| E Gate | `skills/plan-implement-review/scripts/regression-gate.sh` (`review` §4) | Orchestrator |
| V Verify | `verify-change` (alias `verify`) | Orchestrator |
| F Watch | `watch` | Orchestrator, self-paced |
| G Monitor | `monitor` | Orchestrator, self-paced, read-only, starts after change deployed to PROD |

## Phases and aliases

`phases=` picks a contiguous run of the seven skills. Default `plan` through `watch` (PIRVW). `align` and `monitor` only when asked. `pir-args` inserts `verify` after `review` when the run implements or watches. Aliases only set it:

| Phases | Short | Long |
|---|---|---|
| plan → implement | `pi` | `plan-implement` |
| implement → review → verify | `ir` | `implement-review` |
| review → verify → watch | `rw` | `review-watch` |
| plan → implement → review → verify | `pir` | `plan-implement-review` |
| align → plan → implement → review → verify | `apir` | — |
| implement → review → verify → watch | `irw` | `implement-review-watch` |
| plan → implement → review → verify → watch | `pirw`, `pirvw` | `plan-implement-review-watch` |
| align → plan → implement → review → verify → watch | `apirw`, `apirvw` | — |
| align → plan → implement → review → verify → watch → monitor | `apirwm` | — |
| verify | `verify` | `verify-change` |
| monitor | `m` | — |

`plan` alone = `write-plan` (same as `phases=plan`). Other runs via `phases=`, e.g. `phases=align,plan`, `phases=align`, `phases=watch,monitor`.

Starting mid-chain needs that phase's input. Missing → ask once.
- align: task or document
- implement: plan path, ticket, or checklist
- review: branch/PR (+ plan)
- verify: branch/PR (+ plan path)
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
5. Mark proof early: any behavior, screen, backend, or database change → `verify` phase mandatory after review when implement and review both run.

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
- Prompt minimum: repo path, branch, plan path or checklist, "run `implement`", commit often, **do not push**, do not capture proof (`verify` phase owns it), repo rules.
- Before each attempt: `pir-state.sh inc-round` (exit 3 = rounds spent → hand off), then `set implementer_id=… subagent_id=…`.
- Wait on it. Don't poll its transcript.

Parallel slices follow implement §Parallel slices. Orchestrator owns merging and cleanup. Evidence and regression gate run once on integrated branch.

## C–E. Review loop

1. Run `review` on branch. Count blocking findings `k`. Review does not own proof.
2. `skills/plan-implement-review/scripts/verdict.sh --round <r> --max <m> --blocking <k>` → `next`:
   - `gate` → `regression-gate.sh <repo> --base origin/<base>` (exit 3 = dirty tree). `pir-state.sh set regression_status=<status>`. Then `verdict.sh --phase gate --regression <status> …` and follow its `next`.
   - `done` → V.
   - `fix` → write `review-roundN.md`, `inc-round`, resume same implementer, back to 1.
   - `hand_off` → stop. Hand findings + `implementer_id` to user.
   - `wait` → implementer or gate not finished.

## V. Verify

Own stage, after the review loop reaches `done`. Not part of review.

When phases include `verify`: run [`verify-change`](../verify-change/verify-change.md). Docs, comments, renames, formatting, or any diff with no runtime behavior: light path (`kinds: []`, **no behavior change** line, no screenshots or scripts). Otherwise plan sibling folder + a lean PR description (evidence first, then one or two Try it lines). Blocking: `check-pr-body.sh`, `proof-check.sh` (with `kinds.json` when present), `check-evidence-dir.sh` when the folder exists, `evidence-check.sh` for media.

Completion: kinds picked, evidence on the PR, Try it a pointer not a walkthrough. The reviewer's job is looking at that and saying yes.

If only the description is thin: stay in V and fill it. Do not burn a round.

If the product is wrong (proof shows a failure, or a runtime change with no evidence): count those as blocking `k`. Then `verdict.sh --phase verify --round <vr> --max <vm> --blocking <k>` (`vr` / `vm` = `pir-state.sh get verify_round` / `get max_verify_rounds`, default max 3):

| next | Do |
|---|---|
| `done` | push (feature branch only) → PR/MR body from this phase → F |
| `fix` | `inc-verify-round` (exit 3 → `hand_off`). Write `verify-roundN.md`. Resume the same implementer (`PIR_VERIFY_ROUND=1` if using `run-implementer.sh`). Then C–E using `verify_round` / `max_verify_rounds` for `verdict.sh`, then V again. Up to 3 extra implement → review → verify cycles. Independent of the original `max_rounds` pool |
| `hand_off` | stop. Hand findings + `implementer_id` to the user |

`pi` / `implement-only`: implement §2.6 still proves. Review-only does not insert verify.

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

- Max 3 implement rounds, enforced by `inc-round`. No automatic 4th. Verify may start up to 3 more implement → review cycles (`inc-verify-round`). Watch has own 2 fix rounds.
- Never force-push, merge, approve, or mark ready without being asked.
- Remote branch rewritten under you → never overwrite (see `implement` §1).
- External posts carry attribution prefix.
- Report ≤ 8 lines per tick. Details live in PR/MR description.

## Final report

Plan path (or "no plan") · PR/MR URL · implementer id · rounds used · verify rounds used · verdict · regression status · evidence (count, uncaptured screens) · pipeline state · unresolved threads · fix rounds in watch · monitor verdict (when run).
