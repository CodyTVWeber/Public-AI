# Implementer registry

Profiles for a **cheap / fast / low-effort** coding agent. The orchestrator (stronger model) plans and reviews; the implementer only codes.

## “Spawn” = connected background agent

| Preferred | Fallback |
|-----------|----------|
| Host **background subagent** (`spawn_subagent`, `background: true`) — orchestrator remains connected and can `resume_from` | Detached CLI via `scripts/run-implementer.sh` when no agent API exists |

Always persist **`subagent_id`** (background agent) and/or **`session_id`** (CLI) in `/tmp/pir-<topic>/state.json` for fix rounds.

## Availability check

```bash
command -v grok
command -v claude
# optional: list models
grok models 2>/dev/null | head -20
```

## Profiles

### `grok-4.5-low` — default Grok implementer (cheap/fast)

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `grok-4.5` |
| Effort | **`low`** (`--reasoning-effort low` / `--effort low`) |
| Background agent | `spawn_subagent` with `model: "grok-4.5"`, `background: true`, `description: "[implementer] …"`. If the host cannot set effort on spawn, put `reasoning_effort: low` in the agent prompt and prefer CLI flags when using CLI fallback. |
| Launch (CLI fallback) | `grok --model grok-4.5 --reasoning-effort low --always-approve --session-id <uuid> --max-turns 80 --output-format json --prompt-file <file>` |
| Resume (CLI) | `grok --model grok-4.5 --reasoning-effort low --always-approve --resume <sessionId> --cwd <repo> --max-turns 60 --output-format json --prompt-file <file>` |
| Resume (agent) | `spawn_subagent` + `resume_from: <subagent_id>` + same model; do **not** change effort mid-session |
| Session id | Pre-generate UUID with `--session-id` on launch **or** parse JSON `sessionId` / `session_id`; always write to `state.json` immediately |
| Notes | **Use this when orchestrator is Grok 4.5 high** (or any Grok 4.5 plan/review run). Same model family, lower cost/latency. |

### `composer-2.5` — Grok Composer (if model id available)

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `grok-composer-2.5-fast` (only if `grok models` lists it) |
| Launch / resume | See historical Composer flags; **skip profile** if model id unknown |
| Resume caveat | Composer may bind agent type; resume must use same model |

### `grok-4.5` — full/default effort Grok implementer

| Field | Value |
|-------|--------|
| CLI | `grok` |
| Model | `grok-4.5` |
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
   - Grok 4.5 (high/default) → **`grok-4.5-low`**
   - Claude Sonnet/Opus → **`claude-haiku`**
   - Unknown: first available in order: `grok-4.5-low` → `claude-haiku` → `composer-2.5` → `claude-sonnet` → `grok-4.5`
3. Prefer **background agent** launch; CLI script only as fallback.
4. Always a **separate** agent/process from the orchestrator (isolation + resume).

## Worktrees

If the **project allows** git worktrees and the CLI supports them, optional isolation is fine.

If the project **forbids** worktrees (e.g. Jojo’s `AGENTS.md`), **do not** pass `--worktree`. Implement on the plan/feat branch in the main checkout; orchestrator must not hard-reset that branch mid-run.

## Permissions

Implementer may use auto-approve / skip-permissions **only in its own agent process**. Orchestrator keeps normal project approval rules for prod/migrations.
