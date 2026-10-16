---
name: plan-implement-review
description: Run a capped plan → implement → review loop across one or more repos. Use when the user says "plan implement review", "plan loop", or /plan-implement-review, for non-trivial work needing a durable plan doc plus implementation, or when the user wants a stronger model to plan/review while a cheaper model implements.
argument-hint: "[ticket or task] [optional: plan-builder=, implementer=, max-rounds=]"
---

# Plan → Implement → Review Loop (AI-agnostic)

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

### Default pairing (same product, lower effort)

| Orchestrator (plan + review) | Default implementer |
|------------------------------|---------------------|
| Grok 4.5 **high** (or default high effort) | Background agent: **Grok 4.5 low** (`--reasoning-effort low` / profile `grok-4.5-low`) |
| Grok Composer / unknown Grok | Prefer low effort on available Grok model; else cheapest installed profile |
| Claude Sonnet / Opus orchestrator | Background agent: **Claude Haiku** |
| Explicit `implementer=...` | That profile only |

**Rule:** never default the implementer to the same high-effort model as the orchestrator when a low/cheap variant exists. Always run implement as a **separate background agent** so the orchestrator can still review and resume it.

## Configuration (parse from user message)

| Key | Default | Notes |
|-----|---------|-------|
| `implementer` | cheap/fast for current stack | IDs in `references/implementers.md` (e.g. `grok-4.5-low`) |
| `plan-builder` | `self` | `self` = orchestrator; or a profile id |
| `max-rounds` | `3` | Implement attempts (not review count alone) |
| `plan-only` / `implement-only` / `review-only` | off | Run a single phase |

State directory: `/tmp/pir-<topic>/` with `state.json`:

```json
{
  "topic": "persisted-day-locks",
  "plan_path": "docs/plans/...",
  "plan_branch": "plan/...",
  "plan_pr": "https://...",
  "feat_branch": "feat/...",
  "implement_pr": "https://...",
  "implementer_id": "grok-4.5-low",
  "session_id": "...",
  "subagent_id": "...",
  "reasoning_effort": "low",
  "round": 1,
  "max_rounds": 3,
  "regression_command": "npm run test:system:regression",
  "regression_status": "pending"
}
```

- **`subagent_id`**: host background-agent id (Grok `spawn_subagent` → use with `resume_from`).
- **`session_id`**: CLI session UUID when using CLI fallback; also store if the host exposes one.
- Prefer **one durable id** and always write it to `state.json` after launch for reuse.

## Session continuity (keep implementer context)

Background agents **finish a turn** but context is kept when you **resume the same agent**.

1. Round 1 launch → capture `subagent_id` and/or `session_id`.
2. Rounds 2–3 → **resume same agent** with review feedback (`resume_from=<subagent_id>` or CLI `--resume <session_id>`).
3. Store both in `state.json` when available.
4. Resume **must** use the **same model + same effort** as launch (Grok: model switch can fail with `MODEL_SWITCH_INCOMPATIBLE_AGENT`).

If resume fails: re-launch with full plan path + all prior review notes (degraded; warn user).

Details per profile: `references/implementers.md`.

## Tracker progress comments

When the work came from a **tracker task** (e.g. Asana): [`references/tracker-comments.md`](references/tracker-comments.md) is the canonical format/rules. write-plan, implement, and code-review **reference** that file — do not duplicate it.

- **Before Phase A:** read existing comments; reuse a plan/PR they point to rather than starting over.
- **Who posts:** write-plan, implement, and code-review each post their own milestone comment. If you run a phase without loading that skill, post for that phase. Never two comments for the same milestone.
- No task, no comments.

## Phase A — Plan

Skip if `implement-only` or plan already exists and user says use it.

**Canonical instructions:** sibling skill [`write-plan`](../write-plan/write-plan.md)  
(also installed as `/write-plan`). Do not fork a second plan workflow — load and execute **write-plan** here.

1. If `plan-builder=self` (default): orchestrator runs **write-plan** fully.
2. If `plan-builder=<profile-id>`: spawn that profile as a **background agent** with `write-plan.md` + user task; wait for draft plan PR URL.
3. After success, record in `state.json`: `plan_path`, `plan_branch`, `plan_pr`, `topic`.
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

### Preferred: background agent (connected)

1. Resolve cheap/fast profile (`grok-4.5-low` when orchestrator is Grok 4.5 high).
2. **Round 1:** `spawn_subagent` (or host equivalent) with:
   - `background: true` (orchestrator stays connected; do not block the chat forever without a wait handle)
   - `model` / effort matching the profile (Grok: `grok-4.5` + low reasoning effort when the host supports it; if effort cannot be set on spawn, pass `reasoning_effort: low` in the prompt and use CLI flags when falling back)
   - `description`: `[implementer] <topic> r1`
   - Prompt includes: absolute plan path, branch, implement skill path, one-PR rules, project red lines
   - `capability_mode` that allows code edit + git (not read-only)
3. Save returned **`subagent_id`** → `state.json`.
4. Wait for completion via host wait tool (do not abandon the agent).
5. **Rounds 2–3:** `spawn_subagent` with `resume_from: <subagent_id>` + review feedback file contents; same model/effort.
6. On failure: surface agent output; do not pretend green.
7. Consolidate plan-only vs implement PR per **implement** skill §1.

### Fallback only: detached CLI

Use `scripts/run-implementer.sh` only if background agents are unavailable. Still capture `session_id` for `--resume`. Prefer generating `--session-id` on launch and writing it to `state.json` immediately.

Respect project rules: e.g. **never `git worktree`** if the repo forbids it — run on the plan/feat branch in-repo instead.

### Implementer prompt (minimum)

- Absolute plan path
- Feature branch name + existing PR URL if any
- Path to sibling skill `implement/implement.md` (or “run /implement”)
- **Git cadence (default):** **commit often**, **do not push** unless the user or orchestrator explicitly says push
  - Commit after each meaningful green step (framework, J1, J2 fix, docs) — local checkpoints
  - Do **not** wait for full suite green to make the first commit of WIP
  - Push is orchestrator/user-owned for PIR unless pre-authorized for that run
- “Ensure PR exists only if none; one PR with plan when possible — usually already open”
- “No product changes outside plan; flag plan gaps instead”
- Project `AGENTS.md` / migration rules if present
- “You are the cheap/fast implementer; keep changes minimal and plan-faithful”
- If work came from a tracker task: read/post comments per `references/tracker-comments.md`

## Phase C — Review

1. Review **implement** branch or PR vs plan checklist + base branch.
2. Prefer project review skill if available; else structured findings:
   - Severity: bug | suggestion | nit
   - File:line, description, fix suggestion
3. Verdict:
   - **approve** → Phase E (system regression) — **do not** final-report as done until E finishes
   - **fix required** and `round < max_rounds` → Phase D
   - **fix required** and rounds exhausted → stop; hand issues + `subagent_id` / `session_id` to user; **skip** Phase E unless user asks

Review is **read-only**. Do not apply code fixes in the review step; the implementer applies them.

If a tracker task originated this work, post one **Review rN** comment per `references/tracker-comments.md` unless the review skill already posted.

## Phase D — Feed findings to implementer

1. Write `${STATE}/review-roundN.md` with issues.
2. **Resume** the same background implementer (`round := round + 1`).
3. Return to Phase C after implement exits.

## Plan updates mid-loop

If review finds a **product/plan** gap:

1. Orchestrator (or plan-builder) updates plan doc; commit + push plan PR.
2. Resume implementer: “Plan updated at `<path>`; re-read; implement deltas only.”

## Phase E — System regression (final verification)

**Required after code review approves** (and after the last successful implement push). Orchestrator runs this — not optional “if time.”

### Command

1. Resolve from project docs, in order:
   - Explicit npm/script named in `AGENTS.md` / `docs/rules/testing.md` / `tests/system/README.md` as **PIR end gate** or **system regression**
   - Default for this product when present: **`npm run test:system:regression`**
2. If no system-regression script exists in the repo: record `regression_status: skipped` + reason in the final report; still run `npm run lint && npm run test` (or project equivalent) if not already green on the tip commit.
3. Store chosen command in `state.json` → `regression_command`.

### When to run

| Situation | Run Phase E? |
|-----------|----------------|
| Review **approve** (any round) | **Yes** — always |
| Docs-only / plan-only (no app code) | Prefer run if cheap; may skip with explicit note if zero runtime surface |
| `review-only` / `plan-only` flags | No (unless user asks) |
| Rounds exhausted without approve | No (unless user asks) |
| Regression fails | **Not done** — treat as review fail: Phase D if rounds remain, else hand failures to user |

### How

1. On the **implement branch** tip (clean tree preferred).
2. Run the resolved command (full boot + happy paths; do not substitute unit tests alone).
3. On **pass**: `regression_status: passed` → Final report.
4. On **fail**: `regression_status: failed`; capture log tail; if `round < max_rounds`, Phase D with regression failures as fix list; else stop and report.
5. Do **not** claim PIR complete, or merge-ready, without pass or an explicit user skip.

### Implementer prompt addition

Include: “Unit/lint green is required each commit; **orchestrator** runs `npm run test:system:regression` (or project PIR gate) after review approve — you may run it if local Supabase is up and it speeds feedback.”

## Round budget

| Implement attempt | After |
|-------------------|--------|
| 1 | First code from plan |
| 2 | First fix pass |
| 3 | Last fix pass |
| stop | Approve **+ Phase E** or 3 attempts reviewed |

No automatic 4th implement.

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
