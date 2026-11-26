# plan-implement-review

AI-agnostic **plan → implement → review** loop (max 3 implement/review rounds).

Works from Grok, Claude Code, Cursor, or any agent that can:

1. Write/edit plan markdown and ensure a PR exists (create only if none for that branch)
2. **Spawn a cheap/fast implementer as a background agent** the orchestrator stays connected to
3. Review the implement branch/PR
4. **Resume the same implementer agent** with review feedback (context preserved)
5. After approve: **system regression** (`npm run test:system:regression` or project PIR gate) before reporting done

When the work came from a **tracker task**, post one short progress comment per plan / implement-round / review milestone. Canonical format: [references/tracker-comments.md](references/tracker-comments.md). Sibling [write-plan](../write-plan/), [implement](../implement/), and [code-review](../code-review/) reference that file.

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
| Grok 4.5 high | **Grok 4.5 medium** (`grok-medium`; `grok-low` for mechanical plans) |
| Claude Sonnet/Opus | **Claude Haiku** |

## Built-in implementer profiles

See [references/implementers.md](references/implementers.md).

| ID | Typical use |
|----|-------------|
| `grok-medium` | **Default Grok implementer** (same model, medium effort) |
| `grok-low` | Mechanical plans (same model, low effort) |
| `claude-haiku` | **Default Claude implementer** |
| `composer-2.5` | Grok Composer if model id available |
| `claude-sonnet` | Stronger Claude when forced |
| `grok-4.5` | Full-effort Grok when forced |

## Install

### Grok

```bash
ln -sfn <path-to-this-repo>/skills/plan-implement-review ~/.grok/skills/plan-implement-review
ln -sfn plan-implement-review.md ~/.grok/skills/plan-implement-review/SKILL.md
chmod +x ~/.grok/skills/plan-implement-review/scripts/*.sh
```

### Claude Code

```bash
cp <path-to-this-repo>/skills/plan-implement-review/plan-implement-review.md \
  ~/.claude/commands/plan-implement-review.md
mkdir -p ~/.claude/skills/plan-implement-review
cp -R <path-to-this-repo>/skills/plan-implement-review/scripts \
  ~/.claude/skills/plan-implement-review/
cp -R <path-to-this-repo>/skills/plan-implement-review/references \
  ~/.claude/skills/plan-implement-review/
```

## Invoke

- `/plan-implement-review`
- “Write a plan, implement with a background low agent, review up to 3 times”
- “Plan loop with implementer grok-low”

Optional args:

- `implementer=grok-medium|grok-low|haiku|sonnet|<other profile id>`
- `plan-builder=self|…`
- `max-rounds=3`
- `plan-only` / `implement-only` / `review-only`

## Files

| Path | Purpose |
|------|---------|
| `plan-implement-review.md` | Agent instructions (`SKILL.md` symlink) |
| `references/implementers.md` | Profiles, selection, resume |
| `references/tracker-comments.md` | Shared tracker progress-comment format (Plan / Implement rN / Review rN) |
| `scripts/run-implementer.sh` | CLI **fallback** launch/resume |
| `scripts/lib-forge.sh` | Shared helpers sourced by the forge scripts below |
| `scripts/forge-ctx.sh` | Host (GitLab/GitHub), project, branch, base, clean/dirty, behind/ahead as JSON |
| `scripts/fresh-branch.sh` | Fetch, refuse a dirty tree, `checkout -b` from the remote default |
| `scripts/pr-find.sh` | Open PR/MR for a head or topic: `reuse` / `conflict` / `create` (never creates) |
| `scripts/diff-scope.sh` | Docs/UI/backend/DB/test-only flags from changed paths |
| `scripts/mr-state.sh` | PR/MR state, pipeline, human threads, behind count, `next` action |
| `scripts/ci-failure-tail.sh` | Trimmed log tail of a failed CI job |
| `scripts/branch-behind.sh` | Behind/ahead and merge-conflict probe without touching the working tree |
| `scripts/tests/*.test.sh` | Plain-bash tests (temp repos, stubbed `glab`/`gh`); each script also has `--help` |

These scripts are read-only or local-git-only: they never push, merge, create PRs/MRs, or post comments. Exit codes: 0 ok, 1 check failed, 2 usage, 3 precondition.
