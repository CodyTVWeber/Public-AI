# plan-implement-review

AI-agnostic **plan → implement → review** loop (max 3 implement/review rounds).

Works from Grok, Claude Code, Cursor, or any agent that can:

1. Write/edit plan markdown and ensure a PR exists (create only if none for that branch)
2. **Spawn a cheap/fast implementer as a background agent** the orchestrator stays connected to
3. Review the implement branch/PR
4. **Resume the same implementer agent** with review feedback (context preserved)
5. After approve: **system regression** (`npm run test:system:regression` or project PIR gate) before reporting done

When the work came from a **tracker task** (e.g. Asana), post short progress comments on that task. Format and rules live in [references/tracker-comments.md](references/tracker-comments.md); sibling skills link there instead of copying them.

## “Spawn” means connected background agent

Not a detached `nohup` process. Prefer host tools:

- Grok: `spawn_subagent` with `background: true`, then wait / `resume_from`
- Claude: background agent / Task with resume
- CLI `scripts/run-implementer.sh`: **fallback only**

Always keep **`subagent_id` and/or `session_id`** in `/tmp/pir-<topic>/state.json`.

## Roles

| Role | Default | Purpose |
|------|---------|---------|
| **Orchestrator** | The AI that invoked the skill (stronger / high effort) | Runs the loop, reviews, feeds findings |
| **Plan builder** | Same as orchestrator unless overridden | Sibling [write-plan](../write-plan/) |
| **Implementer** | **Cheap/fast background agent** | Codes from plan; commits + pushes |

### Default pairing

| Orchestrator | Implementer |
|--------------|-------------|
| Grok 4.5 high | **Grok 4.5 low** (`grok-4.5-low`) |
| Claude Sonnet/Opus | **Claude Haiku** |

## Built-in implementer profiles

See [references/implementers.md](references/implementers.md).

| ID | Typical use |
|----|-------------|
| `grok-4.5-low` | **Default Grok implementer** (same model, low effort) |
| `claude-haiku` | **Default Claude implementer** |
| `composer-2.5` | Grok Composer if model id available |
| `claude-sonnet` | Stronger Claude when forced |
| `grok-4.5` | Full-effort Grok when forced |

## Install

### Grok

```bash
ln -sfn /Users/user/code/AI/skills/plan-implement-review ~/.grok/skills/plan-implement-review
ln -sfn plan-implement-review.md ~/.grok/skills/plan-implement-review/SKILL.md
chmod +x ~/.grok/skills/plan-implement-review/scripts/*.sh
```

### Claude Code

```bash
cp /Users/user/code/AI/skills/plan-implement-review/plan-implement-review.md \
  ~/.claude/commands/plan-implement-review.md
mkdir -p ~/.claude/skills/plan-implement-review
cp -R /Users/user/code/AI/skills/plan-implement-review/scripts \
  ~/.claude/skills/plan-implement-review/
cp -R /Users/user/code/AI/skills/plan-implement-review/references \
  ~/.claude/skills/plan-implement-review/
```

## Invoke

- `/plan-implement-review`
- “Write a plan, implement with a background low agent, review up to 3 times”
- “Plan loop with implementer grok-4.5-low”

Optional args:

- `implementer=grok-4.5-low|haiku|sonnet|composer-2.5|grok-4.5|<custom>`
- `plan-builder=self|…`
- `max-rounds=3`
- `plan-only` / `implement-only` / `review-only`

## Files

| Path | Purpose |
|------|---------|
| `plan-implement-review.md` | Agent instructions (`SKILL.md` symlink) |
| `references/implementers.md` | Profiles, selection, resume |
| `references/tracker-comments.md` | Shared tracker-task comment format/rules |
| `scripts/run-implementer.sh` | CLI **fallback** launch/resume |
