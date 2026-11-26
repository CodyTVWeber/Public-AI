# Implementer registry

Profiles for a **cheap / fast / low-effort** coding agent. The orchestrator (stronger model) plans and reviews; the implementer only codes.

## “Spawn” = connected background agent

| Preferred | Fallback |
|-----------|----------|
| Host **background subagent** (`spawn_subagent`, `background: true`) — orchestrator remains connected and can `resume_from` | Detached CLI via `scripts/run-implementer.sh` when no agent API exists |

Always persist **`subagent_id`** (background agent) and/or **`session_id`** (CLI) with `skills/plan-implement-review/scripts/pir-state.sh set` (state: `/tmp/pir-<topic>/state.json`) for fix rounds. `run-implementer.sh` does this itself.

## Availability check

```bash
command -v grok
command -v claude
# optional: list models
grok models 2>/dev/null | head -20
```

## Profiles

### `grok-medium` — default Grok implementer

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `<grok model>` |
| Effort | **`medium`** (`--reasoning-effort medium`); same launch and resume shapes as `grok-low` with `medium` substituted |
| Notes | Default for plans touching more than one file or any logic. Same model family as a Grok 4.5 orchestrator, lower cost |

### `grok-low` — Grok implementer for mechanical plans

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `<grok model>` |
| Effort | **`low`** (`--reasoning-effort low` / `--effort low`) |
| Background agent | `spawn_subagent` with `model: "<grok model>"`, `background: true`, `description: "[implementer] …"`. If the host cannot set effort on spawn, put `reasoning_effort: low` in the agent prompt and prefer CLI flags when using CLI fallback. |
| Launch (CLI fallback) | `grok --model <grok model> --reasoning-effort low --always-approve --session-id <uuid> --max-turns 80 --output-format json --prompt-file <file>` |
| Resume (CLI) | `grok --model <grok model> --reasoning-effort low --always-approve --resume <sessionId> --cwd <repo> --max-turns 60 --output-format json --prompt-file <file>` |
| Resume (agent) | `spawn_subagent` + `resume_from: <subagent_id>` + same model; do **not** change effort mid-session |
| Session id | Pre-generate UUID with `--session-id` on launch **or** parse JSON `sessionId` / `session_id`; write it with `pir-state.sh set session_id=…` immediately |
| Notes | **Use this when orchestrator is Grok 4.5 high** (or any Grok 4.5 plan/review run). Same model family, lower cost/latency. |

### `composer-2.5` — Grok Composer (if model id available)

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `<composer model>` (only if `grok models` lists it) |
| Launch / resume | See historical Composer flags; **skip profile** if model id unknown |
| Resume caveat | Composer may bind agent type; resume must use same model |

### `grok-4.5` — full/default effort Grok implementer

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `<grok model>` |
| Effort | default/high (omit `--reasoning-effort low`) |
| Notes | **Only** when user forces `implementer=grok-4.5` or low path is broken. Not the default. |

### `claude-haiku` — default Claude implementer (cheap)

| Field | Value |
|-------|--------|
| CLI | `claude` |
| Model | `haiku` |
| Background agent | Host Claude background agent / Task with Haiku when available |
| Launch (CLI) | `claude -p --model haiku --dangerously-skip-permissions --output-format json --session-id <uuid> "$(cat prompt)"` |
| Resume | `claude -p --resume <sessionId> --dangerously-skip-permissions --output-format json "$(cat feedback)"` |
| Notes | Prefer when orchestrator is Claude Sonnet/Opus |

### `claude-sonnet` — stronger Claude implementer

| Field | Value |
|-------|--------|
| CLI | `claude` |
| Model | `sonnet` |
| Notes | Only if user asks or Haiku fails / task is too hard for Haiku |

## Selection algorithm

1. If user set `implementer=<id>`, use it (error if CLI/model missing).
2. Else detect **orchestrator stack** and pick the **cheap pair**:
   - Grok 4.5 (high/default) → **`grok-medium`**; **`grok-low`** when the plan is mechanical (see Effort and context)
   - Claude Sonnet/Opus → **`claude-haiku`**
   - Unknown: first available in order: `grok-medium` → `grok-low` → `claude-haiku` → the Composer profile → `claude-sonnet` → the full-effort Grok profile
3. Prefer **background agent** launch; CLI script only as fallback.
4. Always a **separate** agent/process from the orchestrator (isolation + resume).

## Effort and context

| Rule | Value |
|---|---|
| Default effort | `medium` where the host sets effort |
| `low` | Mechanical plan: renames, docs, config, one file, no new logic |
| `high` | Never auto-selected. Two failed rounds at `medium` mean the plan is unclear or the task needs the orchestrator; hand back instead of raising effort |
| Context cap | 200k tokens per implementer agent; `implement` §Budget defines the checkpoint |
| Effort changes | Never mid-session; a fresh agent after a handoff may pick again |

## Worktrees

Do not pass `--worktree` for the single implementer: it works on the plan/feat branch in the main checkout, and the orchestrator does not hard-reset that branch mid-run. Worktrees are allowed only for parallel implement slices (implement §Parallel slices) and are merged and removed before the phase ends; a repo that forbids worktrees uses `--mode clone`.

## Permissions

Implementer may use auto-approve / skip-permissions **only in its own agent process**. Orchestrator keeps normal project approval rules for prod/migrations.
