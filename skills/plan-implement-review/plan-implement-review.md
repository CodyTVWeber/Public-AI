---
name: plan-implement-review
description: Run a capped plan → implement → review loop across one or more repos. Use when the user says "plan implement review", "plan loop", or /plan-implement-review, for non-trivial work needing a durable plan doc plus implementation, or when the user wants a stronger model to plan/review while a cheaper model implements.
argument-hint: "[ticket or task] [optional: plan-builder=, implementer=, max-rounds=]"
---

# Plan → Implement → Review Loop (AI-agnostic)

With a final PR/MR watch and UI screenshot evidence, use [plan-implement-review-watch](../plan-implement-review-watch/).

Run a capped loop: **plan → cheap/fast implementer (background agent) → review → resume implementer with fixes → system regression**. Max **3** implement attempts (each followed by review). Stop early on approve, then **always** run the final regression gate before reporting done.

This skill is **provider-agnostic**. Prefer **connected background agents** over detached shell processes.

## When to use

- User says “plan implement review”, “plan loop”, `/plan-implement-review`
- Non-trivial work that needs a durable plan PR **and** implementation
- User wants a **lighter/cheaper/faster** model to implement while a stronger model plans/reviews

## “Spawn” means background agent (connected)

When this skill (or the user) says **spawn** implementer, that means:

| Do | Don’t |
|----|--------|
| Launch a **background subagent** the orchestrator stays connected to | Fire-and-forget `nohup` / detached CLI with no tool channel back |
| Use host primitives: Grok `spawn_subagent` (`background: true`), Claude Task/background agent, etc. | Assume “spawn” = only `scripts/run-implementer.sh` |
| Wait via host wait/poll on that agent (`get_command_or_subagent_output`, task notifications) | Poll blind PID only and lose transcript |
| **Resume the same agent** with `resume_from` / same `session_id` / subagent id for fix rounds | New cold agent every round unless resume failed |

**Orchestrator stays in charge:** plan, review, stop conditions, user updates. Implementer only writes code/commits/pushes on the feature branch.

Detached CLI (`scripts/run-implementer.sh`) is a **fallback** when the host has no background-agent API — not the default.

## Roles

| Role | Who | Responsibility |
|------|-----|----------------|
| **Orchestrator** | The agent that loaded this skill | Drive phases, **review**, **final regression**, stop conditions, user updates |
| **Plan builder** | Default = orchestrator; override if user sets `plan-builder=...` | Write plan doc, commit, push, draft plan PR |
| **Implementer** | **Background agent**, cheap/fast profile | Code from plan, unit/lint, **commit often**; push only when user/orchestrator says so |

If the user does **not** specify `plan-builder`, the **current agent is the plan builder** (no extra spawn).

If the user does **not** specify `implementer`, pick the **cheap/fast implementer for the current stack** — see selection algorithm in `references/implementers.md`.

### Default pairing (same product, medium effort)

| Orchestrator (plan + review) | Default implementer |
|------------------------------|---------------------|
| Grok 4.5 **high** (or default high effort) | Background agent: **Grok 4.5 medium** (`--reasoning-effort medium` / profile `grok-medium`); `grok-low` for mechanical plans |
| Grok Composer / unknown Grok | Prefer medium effort on available Grok model; else cheapest installed profile |
| Claude Sonnet / Opus orchestrator | Background agent: **Claude Haiku** |
| Explicit `implementer=...` | That profile only |

**Rule:** never default the implementer to the same high-effort model as the orchestrator when a low/cheap variant exists. Always run implement as a **separate background agent** so the orchestrator can still review and resume it.

## Configuration (parse from user message)

`skills/plan-implement-review/scripts/pir-args.sh --default plan,implement,review "<args>"` → JSON `{phases, ticket, plan_builder, no_plan, implementer, fix_comments, max_rounds, window, cadence, task}`. Exit 2 (unknown phase, gap in phases, bad value) → ask once.

| Key | Default | Notes |
|-----|---------|-------|
| `implementer` | cheap/fast for current stack | IDs in `references/implementers.md` (e.g. `grok-medium`) |
| `plan-builder` | `self` | `self` = orchestrator; or a profile id |
| `max-rounds` | `3` | Implement attempts (not review count alone) |
| `phases=` · `plan-only` / `implement-only` / `review-only` | `plan,implement,review` | Contiguous run of `align`, `plan`, `implement`, `review`, `watch`, `monitor` (+ `window=`, `cadence=` for monitor); aliases (`apirw`, `apirwm`, `pi`, `ir`, …) in [plan-implement-review-watch](../plan-implement-review-watch/) |

State: `skills/plan-implement-review/scripts/pir-state.sh init --topic <topic> --max-rounds <n>` creates `/tmp/pir-<topic>/state.json` (exit 3 = exists → `get`). Read and write only through `pir-state.sh get [KEY]` · `set KEY=VALUE…` · `status`; never hand-edit. Keys:

```json
{
  "topic": "persisted-day-locks",
  "plan_path": "docs/plans/...",
  "plan_branch": "plan/...",
  "plan_pr": "https://...",
  "feat_branch": "feat/...",
  "implement_pr": "https://...",
  "implementer_id": "grok-medium",
  "session_id": "...",
  "subagent_id": "...",
  "reasoning_effort": "medium",
  "context_cap_tokens": 200000,
  "round": 1,
  "max_rounds": 3,
  "regression_command": "make regression",
  "regression_status": "pending"
}
```

- **`subagent_id`**: host background-agent id (use with `resume_from`). **`session_id`**: CLI/host session id.
- Write the id right after launch (`pir-state.sh set subagent_id=<id>`); prefer one durable id.

## Effort and context budget

- Implementer effort defaults to `medium`; `low` only for mechanical plans; never auto-raised to `high` ([implementers](references/implementers.md))
- Context cap 200k tokens per implementer agent (`context_cap_tokens` in state). The implementer checkpoints at about 150k per `implement` §Budget; the orchestrator then launches a fresh agent (same profile) with the plan and `handoff.md` instead of resuming

## Session continuity (keep implementer context)

Background agents **finish a turn** but context is kept when you **resume the same agent**.

1. Round 1 launch → capture `subagent_id` and/or `session_id`.
2. Rounds 2–3 → **resume same agent** with review feedback (`resume_from=<subagent_id>` or CLI `--resume <session_id>`).
3. Resume **must** use the **same model + same effort** as launch (Grok: model switch can fail with `MODEL_SWITCH_INCOMPATIBLE_AGENT`).

If resume fails: re-launch with full plan path + all prior review notes (degraded; warn user).

Details per profile: `references/implementers.md`.

## Tracker comments (when work came from a task)

Canonical rules: [`references/tracker-comments.md`](references/tracker-comments.md). Sibling **write-plan**, **implement**, and **code-review** reference that file — do not fork a second format.

- **Before Phase A:** read the task’s comments; reuse any plan/PR they point to
- Milestones: **Plan** (after A), **Implement rN** (after each B), **Review rN** (after each C). The finishing skill posts; orchestrator only if it did not

Body: `skills/plan-implement-review/scripts/tracker-comment.sh <Plan|Implement rN|Review rN> <status> <url> [human-action]` prints it (≤3 lines, never posts); you post it.

No task, no comments. Comments only — never otherwise edit the tracker task.

## Phase A — Plan

Skip if `implement-only` or plan already exists and user says use it.

**Canonical instructions:** sibling skill [`write-plan`](../write-plan/write-plan.md)  
(also installed as `/write-plan`). Do not fork a second plan workflow — load and execute **write-plan** here.

1. If `plan-builder=self` (default): orchestrator runs **write-plan** fully.
2. If `plan-builder=<profile-id>`: spawn that profile as a **background agent** with `write-plan.md` + user task; wait for draft plan PR URL.
3. After success: `pir-state.sh set plan_path=… plan_branch=… plan_pr=…`.
4. Respect project red lines (migrations immutable, no force-push through conflicts, approval before risky deploys).

### Research ownership — reasoning-heavy work belongs to the planner, not the orchestrator

When a user assigns explicit model tiers to roles (e.g. `plan-builder=opus`, cheap implementer), the **orchestrator must not pre-digest the substantive research itself** — even research done *before* Phase A formally starts, if it feeds the plan.

- **Orchestrator/cheap scouts may do:** narrow, mechanical fact-finding — grep for a symbol, confirm a file/endpoint exists, list call sites.
- **Planner (assigned tier, e.g. Opus) must do:** anything requiring synthesis or judgment — reconciling contradictory findings across repos, deciding whether a code path is truly dead, checking whether one endpoint is a superset/replacement of another, cross-repo dead-code verification.
- If the orchestrator finds itself weighing evidence, resolving a contradiction, or forming a verdict ("safe to remove" / "not superseded") rather than just reporting a grep result — stop and hand that work to the planner instead of finishing it solo.
- Rationale: this reasoning *is* planning. Doing it outside Phase A with the wrong model tier defeats the point of the user assigning tiers to roles, and produces a plan the assigned planner never actually vetted.

## Phase B — Implement (round N)

**Canonical instructions:** sibling skill [`implement`](../implement/implement.md)  
(also installed as `/implement`). Do not fork a second implement workflow — load and execute **implement** via the implementer agent.

Before every attempt (launch or resume): `skills/plan-implement-review/scripts/pir-state.sh inc-round --topic <topic>`. Exit 3 = rounds spent → hand off; never a 4th attempt. `run-implementer.sh` does this itself.

### Preferred: background agent (connected)

1. Resolve cheap/fast profile (`grok-medium` when orchestrator is Grok 4.5 high; `grok-low` for a mechanical plan).
2. **Round 1:** `spawn_subagent` (or host equivalent) with:
   - `background: true` (orchestrator stays connected; do not block the chat forever without a wait handle)
   - `model` / effort matching the profile (Grok: `<grok model>` + medium reasoning effort when the host supports it; if effort cannot be set on spawn, pass `reasoning_effort: medium` in the prompt and use CLI flags when falling back)
   - `description`: `[implementer] <topic> r1`
   - Prompt includes: absolute plan path, branch, implement skill path, one-PR rules, project red lines
   - `capability_mode` that allows code edit + git (not read-only)
3. Save returned **`subagent_id`** (`pir-state.sh set subagent_id=<id> implementer_id=<profile>`).
4. Wait for completion via host wait tool (do not abandon the agent).
5. **Rounds 2–3:** `spawn_subagent` with `resume_from: <subagent_id>` + review feedback file contents; same model/effort.
6. On failure: surface agent output; do not pretend green.
7. Consolidate plan-only vs implement PR per **implement** skill §1.

### Fallback only: detached CLI

Use `skills/plan-implement-review/scripts/run-implementer.sh` only if background agents are unavailable. It validates the profile and CLI first, counts the round and stores `session_id` via `pir-state.sh`, and prints JSON `{round, profile, model, session_id, exit_code, out, err}`. Exit 3 = rounds spent; exit 1 = implementer CLI failed (see `err`).

Respect project rules: if the repo forbids worktrees, parallel slices use `--mode clone`. Otherwise isolated work = a fresh clone; worktrees are allowed only for parallel implement slices (implement §Parallel slices) and are merged and removed before the phase ends.

### Implementer prompt (minimum)

- Absolute plan path
- Feature branch name + existing PR URL if any
- Path to sibling skill `implement/implement.md` (or “run /implement”)
- **Git cadence:** **commit often** (each meaningful green step; WIP counts); **do not push** unless the user or orchestrator says so — push is orchestrator-owned unless pre-authorized
- “Ensure PR exists only if none; one PR with plan when possible — usually already open”
- “No product changes outside plan; flag plan gaps instead”
- Project `AGENTS.md` / migration rules if present
- “You are the cheap/fast implementer; keep changes minimal and plan-faithful”
- Commit messages in the repo's numbered format: `skills/plan-implement-review/scripts/commit-msg.sh <branch> <item>...`
- If work came from a tracker task: one **Implement rN** comment per sibling `plan-implement-review/references/tracker-comments.md` — comments only, never edit the task

## Phase C — Review

1. Review **implement** branch or PR vs plan checklist + base branch.
2. Prefer project review skill if available; else structured findings:
   - Severity: bug | suggestion | nit
   - File:line, description, fix suggestion
3. Count blocking findings (bug severity or missing proof) `k`, then `skills/plan-implement-review/scripts/verdict.sh --round <r> --max <m> --blocking <k>` → `{next, reason}` (`r`, `m` = `pir-state.sh get round` / `get max_rounds`):

| next | Do |
|---|---|
| `gate` | Phase E — **do not** final-report as done until E finishes |
| `fix` | Phase D |
| `hand_off` | Stop; hand issues + `subagent_id` / `session_id` to user; **skip** Phase E unless asked |
| `wait` | Implementer not finished |

Review is **read-only**. Do not apply code fixes in the review step; the implementer applies them.

After the verdict: **Review rN** tracker comment if this work came from a task (`references/tracker-comments.md`).

## Phase D — Feed findings to implementer

1. Write `${STATE}/review-roundN.md` with issues.
2. `inc-round`, then **resume** the same background implementer.
3. Return to Phase C after implement exits.

## Plan updates mid-loop

If review finds a **product/plan** gap:

1. Orchestrator (or plan-builder) updates plan doc; commit + push plan PR.
2. Resume implementer: “Plan updated at `<path>`; re-read; implement deltas only.”

## Phase E — System regression (final verification)

**Required after code review approves** (and after the last successful implement push). Orchestrator runs this — not optional “if time.”

### Command

`skills/plan-implement-review/scripts/regression-gate.sh <repo-dir> --base origin/<base>` → `{status, command, source, log_tail}`. Exit 3 = dirty tree → commit/stash first.

- Discovery order (also in `--help`): documented gate → explicit regression script/target → lint → typecheck → unit-test chain. Nothing found → `skipped`: give the reason in the final report
- `pir-state.sh set regression_status=<status> regression_command=<command>`
- `failed` + `pre_existing: true` (same failures on base) → report, don't block
- Then `verdict.sh --phase gate --regression <status> --round <r> --max <m> --blocking 0`

### When to run

| Situation | Run Phase E? |
|-----------|----------------|
| Review **approve** (any round) | **Yes** — always |
| Docs-only / plan-only (no app code) | Prefer run if cheap; may skip with explicit note if zero runtime surface |
| `review-only` / `plan-only` flags, or rounds exhausted without approve | No (unless user asks) |

Run on the **implement branch** tip; never substitute unit tests alone when a full regression exists. `done` → Final report. `fix` → Phase D with the log tail as fix list. `hand_off` → stop and report. Never call PIR complete or merge-ready without a pass or an explicit user skip.

### Implementer prompt addition

Include: “Unit/lint green is required each commit; **orchestrator** runs the project regression gate after review approve — you may run it if its local dependencies are up and it speeds feedback.”

## Round budget

Attempt 1 = first code; 2–3 = fix passes. Stop on approve **+ Phase E**, or when 3 attempts are reviewed. No automatic 4th implement: `inc-round` exits 3 at `round == max_rounds`.

## Safety

- No force-push; no migration rewrite of applied history; no secret commits
- Implementer may push **feature** branches only
- Orchestrator confirms before production deploys / `db push` to PROD if project requires it
- Do not run implementer with broader permissions than needed

## Final report to user

- Plan PR + implement PR
- Implementer id + **`subagent_id` / `session_id`** (for manual resume)
- Rounds used
- Verdict + remaining issues
- **Regression:** command run + `passed` / `failed` / `skipped` (reason)

## Install note for Grok

Grok loads `SKILL.md`. Copy or symlink this file to  
`~/.grok/skills/plan-implement-review/SKILL.md` (see README).
