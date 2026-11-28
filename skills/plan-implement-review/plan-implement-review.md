---
name: plan-implement-review
description: Run a capped plan → implement → review loop across one or more repos. Use when the user says "plan implement review", "plan loop", or /plan-implement-review, for non-trivial work needing a durable plan doc plus implementation, or when the user wants a stronger model to plan/review while a cheaper model implements.
argument-hint: "[ticket or task] [optional: plan-builder=, implementer=, max-rounds=]"
---

# Plan → Implement → Review Loop (AI-agnostic)

Need final PR/MR watch and UI screenshot evidence → [plan-implement-review-watch](../plan-implement-review-watch/).

Capped loop: **plan → cheap/fast implementer (background agent) → review → resume implementer with fixes → system regression → verify**. Max **3** implement attempts, each followed by review. Approve → stop early, but **always** run final regression gate, then verify, before reporting done.

Provider-agnostic. Prefer **connected background agents** over detached shell processes.

## When to use

- "plan implement review", "plan loop", `/plan-implement-review`
- Non-trivial work needing durable plan PR **and** implementation
- Cheaper/faster model implements while stronger model plans/reviews

## "Spawn" = background agent (connected)

| Do | Don't |
|----|--------|
| Launch **background subagent** orchestrator stays connected to | Fire-and-forget `nohup` / detached CLI with no tool channel back |
| Host primitives: Grok `spawn_subagent` (`background: true`), Claude Task/background agent, etc. | Assume "spawn" = only `scripts/run-implementer.sh` |
| Wait via host wait/poll (`get_command_or_subagent_output`, task notifications) | Poll blind PID only, lose transcript |
| **Resume same agent** (`resume_from` / same `session_id` / subagent id) for fix rounds | Cold agent every round unless resume failed |

- **Orchestrator stays in charge:** plan, review, stop conditions, user updates.
- Implementer writes code, commits, pushes on feature branch only.
- Detached CLI (`scripts/run-implementer.sh`) = **fallback** when host has no background-agent API.

## Roles

| Role | Who | Responsibility |
|------|-----|----------------|
| **Orchestrator** | Agent that loaded this skill | Drive phases, **review**, **final regression**, stop conditions, user updates |
| **Plan builder** | Default = orchestrator; override `plan-builder=...` | Write plan doc, commit, push, draft plan PR |
| **Implementer** | **Background agent**, cheap/fast profile | Code from plan, unit/lint, **commit often**; push only when user/orchestrator says |

- No `plan-builder` given → current agent is plan builder (no extra spawn).
- No `implementer` given → cheap/fast for current stack. See selection in `references/implementers.md`.

### Default pairing (same product, medium effort)

| Orchestrator (plan + review) | Default implementer |
|------------------------------|---------------------|
| Grok 4.5 **high** (or default high effort) | Background agent: **Grok 4.5 medium** (`--reasoning-effort medium` / profile `grok-medium`); `grok-low` for mechanical plans |
| Grok Composer / unknown Grok | Medium effort on available Grok model; else cheapest installed profile |
| Claude Sonnet / Opus orchestrator | Background agent: **Claude Haiku** |
| Explicit `implementer=...` | That profile only |

**Rule:** never default implementer to same high-effort model as orchestrator when low/cheap variant exists. Always run implement as **separate background agent** so orchestrator can review and resume it.

## Configuration (parse from user message)

`skills/plan-implement-review/scripts/pir-args.sh --default plan,implement,review "<args>"` → JSON `{phases, ticket, plan_builder, no_plan, implementer, fix_comments, max_rounds, window, cadence, task}`. Exit 2 (unknown phase, gap in phases, bad value) → ask once.

| Key | Default | Notes |
|-----|---------|-------|
| `implementer` | cheap/fast for current stack | IDs in `references/implementers.md` (e.g. `grok-medium`) |
| `plan-builder` | `self` | `self` = orchestrator; or profile id |
| `max-rounds` | `3` | Implement attempts (not review count alone) |
| `phases=` · `plan-only` / `implement-only` / `review-only` / `verify-only` | `plan,implement,review` (verify is inserted after review) | Contiguous run of `align`, `plan`, `implement`, `review`, `verify`, `watch`, `monitor` (+ `window=`, `cadence=` for monitor). Aliases (`apir`, `apirw`, `apirvw`, `apirwm`, `pi`, `ir`, `pir`, `pirvw`, …) in [plan-implement-review-watch](../plan-implement-review-watch/) |

State: `skills/plan-implement-review/scripts/pir-state.sh init --topic <topic> --max-rounds <n>` creates `/tmp/pir-<topic>/state.json` (exit 3 = exists → `get`). Read and write only via `pir-state.sh get [KEY]` · `set KEY=VALUE…` · `status`. Never hand-edit. Keys:

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

- `subagent_id`: host background-agent id (use with `resume_from`). `session_id`: CLI/host session id.
- Write id right after launch (`pir-state.sh set subagent_id=<id>`). Prefer one durable id.

## Effort and context budget

- Implementer effort `medium`. `low` only for mechanical plans. Never auto-raised to `high` ([implementers](references/implementers.md)).
- Context cap 200k tokens per implementer agent (`context_cap_tokens` in state). Implementer checkpoints at ~150k per `implement` §Budget. Orchestrator then launches fresh agent (same profile) with plan + `handoff.md`, not resume.

## Session continuity (keep implementer context)

Background agents **finish a turn**, but context is kept when you **resume the same agent**.

1. Round 1 launch → capture `subagent_id` and/or `session_id`.
2. Rounds 2–3 → **resume same agent** with review feedback (`resume_from=<subagent_id>` or CLI `--resume <session_id>`).
3. Resume **must** use same model + effort as launch. Grok: model switch can fail with `MODEL_SWITCH_INCOMPATIBLE_AGENT`.

Resume fails → re-launch with full plan path + all prior review notes (degraded; warn user). Details per profile: `references/implementers.md`.

## Tracker comments (when work came from a task)

Canonical rules: [`references/tracker-comments.md`](references/tracker-comments.md). write-plan, implement, code-review reference that file. Don't fork a second format.

- Before Phase A: read task's comments. Reuse any plan/PR they point to.
- Milestones: **Plan** (after A), **Implement rN** (after each B), **Review rN** (after each C). Finishing skill posts. Orchestrator posts only if it didn't.

Body: `skills/plan-implement-review/scripts/tracker-comment.sh <Plan|Implement rN|Review rN> <status> <url> [human-action]` prints it (≤ 3 lines, never posts). You post it.

No task → no comments. Comments only. Never otherwise edit tracker task.

## Phase A: Plan

Skip if `implement-only`, or plan exists and user says use it.

**Canonical:** [`write-plan`](../write-plan/write-plan.md) (also `/write-plan`). Don't fork a second plan workflow. Load and execute **write-plan**.

1. `plan-builder=self` (default): orchestrator runs write-plan fully.
2. `plan-builder=<profile-id>`: spawn that profile as background agent with `write-plan.md` + user task. Wait for draft plan PR URL.
3. Success: `pir-state.sh set plan_path=… plan_branch=… plan_pr=…`.
4. Respect project red lines: migrations immutable, no force-push through conflicts, approval before risky deploys.

### Research ownership: planner, not orchestrator

When user assigns model tiers to roles, **orchestrator must not pre-digest substantive research itself**, even before Phase A starts, if it feeds the plan.

- Orchestrator / cheap scouts may do narrow, mechanical fact-finding: grep a symbol, confirm file/endpoint exists, list call sites.
- Planner (assigned tier, e.g. Opus) must do anything needing synthesis or judgment: reconcile contradictory findings across repos, decide whether a code path is truly dead, check whether one endpoint supersedes another, cross-repo dead-code verification.
- If orchestrator is weighing evidence, resolving a contradiction, or forming a verdict ("safe to remove" / "not superseded") instead of reporting a grep result → stop, hand that to planner.
- Why: this reasoning *is* planning. Doing it solo with the wrong tier defeats the tier assignment and yields a plan the assigned planner never vetted.

## Phase B: Implement (round N)

**Canonical:** [`implement`](../implement/implement.md) (also `/implement`). Don't fork. Load and execute **implement** via implementer agent.

Before every attempt (launch or resume): `skills/plan-implement-review/scripts/pir-state.sh inc-round --topic <topic>`. Exit 3 = rounds spent → hand off. Never a 4th attempt. `run-implementer.sh` does this itself.

### Preferred: background agent (connected)

1. Resolve cheap/fast profile: `grok-medium` when orchestrator is Grok 4.5 high; `grok-low` for mechanical plan.
2. **Round 1:** `spawn_subagent` (or host equivalent) with:
   - `background: true`. Orchestrator stays connected. Don't block chat forever without a wait handle.
   - `model` / effort matching profile. Grok: `<grok model>` + medium reasoning effort when host supports it. If effort can't be set on spawn, pass `reasoning_effort: medium` in prompt and use CLI flags when falling back.
   - `description`: `[implementer] <topic> r1`
   - Prompt: absolute plan path, branch, implement skill path, one-PR rules, project red lines.
   - `capability_mode` allowing code edit + git (not read-only).
3. Save returned **`subagent_id`** (`pir-state.sh set subagent_id=<id> implementer_id=<profile>`).
4. Wait via host wait tool. Don't abandon agent.
5. **Rounds 2–3:** `spawn_subagent` with `resume_from: <subagent_id>` + review feedback file contents. Same model/effort.
6. On failure: surface agent output. Don't pretend green.
7. Consolidate plan-only vs implement PR per **implement** §1.

### Fallback only: detached CLI

Use `skills/plan-implement-review/scripts/run-implementer.sh` only if background agents unavailable. It validates profile and CLI, counts round, stores `session_id` via `pir-state.sh`, prints JSON `{round, profile, model, session_id, exit_code, out, err}`. Exit 3 = rounds spent. Exit 1 = implementer CLI failed (see `err`).

Project rules: repo forbids worktrees → parallel slices use `--mode clone`. Otherwise isolated work = fresh clone. Worktrees only for parallel implement slices (implement §Parallel slices), merged and removed before phase ends.

### Implementer prompt (minimum)

- Absolute plan path
- Feature branch name + existing PR URL if any
- Path to sibling skill `implement/implement.md` (or "run /implement")
- **Git cadence:** **commit often** (each meaningful green step; WIP counts). **Do not push** unless user or orchestrator says so. Push is orchestrator-owned unless pre-authorized.
- "Ensure PR exists only if none; one PR with plan when possible (usually already open)"
- "No product changes outside plan; flag plan gaps instead"
- Project `AGENTS.md` / migration rules if present
- "You are the cheap/fast implementer; keep changes minimal and plan-faithful"
- Commit messages in repo's numbered format: `skills/plan-implement-review/scripts/commit-msg.sh <branch> <item>...`
- Work from tracker task → one **Implement rN** comment per `plan-implement-review/references/tracker-comments.md`. Comments only, never edit task.

## Phase C: Review

Review does not own proof. When implement and review both run, `pir-args` inserts `verify` after this loop. Docs-only diffs use the light path (no screenshots).

1. Review **implement** branch or PR vs plan checklist + base branch.
2. Prefer project review skill. Else structured findings:
   - Severity: bug | suggestion | nit
   - File:line, description, fix suggestion
3. Count blocking findings (bug severity) `k`. Then `skills/plan-implement-review/scripts/verdict.sh --round <r> --max <m> --blocking <k>` → `{next, reason}` (`r`, `m` = `pir-state.sh get round` / `get max_rounds`):

| next | Do |
|---|---|
| `gate` | Phase E. **Do not** final-report done until E finishes |
| `fix` | Phase D |
| `hand_off` | Stop. Hand issues + `subagent_id` / `session_id` to user. **Skip** Phase E unless asked |
| `wait` | Implementer not finished |

Review is **read-only**. Don't apply code fixes in review. Implementer applies them.

After verdict: **Review rN** tracker comment if from a task (`references/tracker-comments.md`).

## Phase D: Feed findings to implementer

1. Write `${STATE}/review-roundN.md` with issues.
2. `inc-round`, then **resume** same background implementer.
3. Return to Phase C after implement exits.

## Plan updates mid-loop

If review finds product/plan gap:

1. Orchestrator (or plan-builder) updates plan doc. Commit + push plan PR.
2. Resume implementer: "Plan updated at `<path>`; re-read; implement deltas only."

## Phase E: System regression (final verification)

**Required after code review approves**, and after last successful implement push. Orchestrator runs it. Not optional "if time."

### Command

`skills/plan-implement-review/scripts/regression-gate.sh <repo-dir> --base origin/<base>` → `{status, command, source, log_tail}`. Exit 3 = dirty tree → commit or stash first.

- Discovery order (also in `--help`): documented gate → explicit regression script/target → lint → typecheck → unit-test chain. Nothing found → `skipped`. Give reason in final report.
- `pir-state.sh set regression_status=<status> regression_command=<command>`
- `failed` + `pre_existing: true` (same failures on base) → report, don't block.
- Then `verdict.sh --phase gate --regression <status> --round <r> --max <m> --blocking 0`

### When to run

| Situation | Run Phase E? |
|-----------|----------------|
| Review **approve** (any round) | **Yes**, always |
| Docs-only / plan-only (no app code) | Prefer if cheap. May skip with explicit note if zero runtime surface |
| `review-only` / `plan-only` flags, or rounds exhausted without approve | No (unless user asks) |

Run on **implement branch** tip. Never substitute unit tests alone when full regression exists. `done` → Phase V when verify is in the run, else Final report. `fix` → Phase D with log tail as fix list. `hand_off` → stop and report. Never call PIR complete or merge-ready without a pass or explicit user skip.

### Implementer prompt addition

"Write to the repo clean-code floors while editing (AGENTS.md guardrails, `.claude/rules/`). Analyzer, lint, and hooks fail the change on a miss. Unit/lint green required each commit. **Orchestrator** runs project regression gate after review approve. You may run it if its local dependencies are up and it speeds feedback."

## Phase V: Verify

Own stage after review and the gate, before watch. Run [`verify-change`](../verify-change/verify-change.md). Completion: kinds picked, evidence on the PR, Try it a pointer. The reviewer's job is looking at that and saying yes. Product wrong → Phase D, then C, then V. Thin description → stay here and fill it.

## Round budget

Attempt 1 = first code. 2–3 = fix passes. Stop on approve **+ Phase E** (+ Phase V when verify is in the run), or when 3 attempts are reviewed. No automatic 4th implement: `inc-round` exits 3 at `round == max_rounds`.

## Safety

- No force-push. No migration rewrite of applied history. No secret commits.
- Implementer pushes **feature** branches only.
- Orchestrator confirms before production deploys or `db push` to PROD, if project requires.
- Don't run implementer with broader permissions than needed.

## Final report to user

- Plan PR + implement PR
- Implementer id + **`subagent_id` / `session_id`** (manual resume)
- Rounds used
- Verdict + remaining issues
- **Regression:** command run + `passed` / `failed` / `skipped` (reason)

## Install note for Grok

Grok loads `SKILL.md`. Copy or symlink this file to `~/.grok/skills/plan-implement-review/SKILL.md` (see README).
