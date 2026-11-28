# Implementer registry

Profiles for cheap / fast / low-effort coding agent. Orchestrator (stronger model) plans and reviews. Implementer only codes.

## "Spawn" = connected background agent

| Preferred | Fallback |
|-----------|----------|
| Host **background subagent** (`spawn_subagent`, `background: true`). Orchestrator stays connected, can `resume_from` | Detached CLI via `scripts/run-implementer.sh` when no agent API exists |

Always persist **`subagent_id`** (background agent) and/or **`session_id`** (CLI) with `skills/plan-implement-review/scripts/pir-state.sh set` (state: `/tmp/pir-<topic>/state.json`) for fix rounds. Feature role uses `subagent_id` / `session_id`. ATDD and script roles use `atdd_subagent_id` / `atdd_session_id` and `script_subagent_id` / `script_session_id`. `run-implementer.sh` is the feature role only.

## Availability check

```bash
command -v grok
command -v claude
# optional: list models
grok models 2>/dev/null | head -20
```

## Profiles

### `grok-medium`: default Grok implementer

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `<grok model>` |
| Effort | **`medium`** (`--reasoning-effort medium`). Same launch and resume shapes as `grok-low` with `medium` substituted |
| Notes | Default for plans touching more than one file or any logic. Same model family as Grok 4.5 orchestrator, lower cost |

### `grok-low`: Grok implementer for mechanical plans

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `<grok model>` |
| Effort | **`low`** (`--reasoning-effort low` / `--effort low`) |
| Background agent | `spawn_subagent` with `model: "<grok model>"`, `background: true`, `description: "[implementer] …"`. If host can't set effort on spawn, put `reasoning_effort: low` in agent prompt. Prefer CLI flags when using CLI fallback |
| Launch (CLI fallback) | `grok --model <grok model> --reasoning-effort low --always-approve --session-id <uuid> --max-turns 80 --output-format json --prompt-file <file>` |
| Resume (CLI) | `grok --model <grok model> --reasoning-effort low --always-approve --resume <sessionId> --cwd <repo> --max-turns 60 --output-format json --prompt-file <file>` |
| Resume (agent) | `spawn_subagent` + `resume_from: <subagent_id>` + same model. Don't change effort mid-session |
| Session id | Pre-generate UUID with `--session-id` on launch, or parse JSON `sessionId` / `session_id`. Write immediately with `pir-state.sh set session_id=…` |
| Notes | **Use when orchestrator is Grok 4.5 high** (or any Grok 4.5 plan/review run). Same model family, lower cost/latency |

### `composer-2.5` — Grok Composer (if model id available)

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `<composer model>` (only if `grok models` lists it) |
| Launch / resume | See Composer flags. **Skip profile** if model id unknown |
| Resume caveat | Composer may bind agent type. Resume must use same model |

### `grok-4.5` — full/default effort Grok implementer

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `<grok model>` |
| Effort | default/high (omit `--reasoning-effort low`) |
| Notes | **Only** when user forces `implementer=grok-4.5` or low path is broken. Not the default. |

### `claude-haiku`: default Claude implementer (cheap)

| Field | Value |
|-------|--------|
| CLI | `claude` |
| Model | `haiku` |
| Background agent | Host Claude background agent / Task with Haiku when available |
| Launch (CLI) | `claude -p --model haiku --dangerously-skip-permissions --output-format json --session-id <uuid> "$(cat prompt)"` |
| Resume | `claude -p --resume <sessionId> --dangerously-skip-permissions --output-format json "$(cat feedback)"` |
| Notes | Prefer when orchestrator is Claude Sonnet/Opus |

### `claude-sonnet`: stronger Claude implementer

| Field | Value |
|-------|--------|
| CLI | `claude` |
| Model | `sonnet` |
| Notes | Only if user asks, or Haiku fails / task too hard for Haiku |

## Selection algorithm

1. User set `implementer=<id>` → use it (error if CLI/model missing).
2. Else detect **orchestrator stack**, pick **cheap pair**:
   - Grok 4.5 (high/default) → **`grok-medium`**. **`grok-low`** when plan is mechanical (see Effort and context).
   - Claude Sonnet/Opus → **`claude-haiku`**.
   - Unknown → first available in order: `grok-medium` → `grok-low` → `claude-haiku` → Composer profile → `claude-sonnet` → full-effort Grok profile.
3. Prefer **background agent** launch. CLI script only as fallback.
4. Always a **separate** agent/process from orchestrator (isolation + resume).

## Effort and context

| Rule | Value |
|---|---|
| Default effort | `medium` where host sets effort |
| `low` | Mechanical plan: renames, docs, config, one file, no logic change |
| `high` | Never auto-selected. Two failed rounds at `medium` = plan unclear or task needs orchestrator. Hand back instead of raising effort |
| Context cap | 200k tokens per implementer agent. `implement` §Budget defines checkpoint |
| Effort changes | Never mid-session. Fresh agent after handoff may pick again |

## Worktrees

Don't pass `--worktree` for single implementer. It works on plan/feat branch in main checkout. Orchestrator doesn't hard-reset that branch mid-run. Worktrees only for parallel implement slices (implement §Parallel slices), merged and removed before phase ends. Repo forbidding worktrees → `--mode clone`.

## Permissions

Implementer may use auto-approve / skip-permissions **only in its own agent process**. Orchestrator keeps normal project approval rules for prod and migrations.
