---
name: implement
description: Implement work from a plan file, ticket, or explicit fix list: code, lint/test green, commit, push, ensure PR exists. Use for "implement the plan", "build this", /implement, or the implementer phase of plan-implement-review.
argument-hint: "[plan path or ticket]"
---

# Implement

Implement work from **plan file**, Asana task, or user fix list: code, lint/test green, commit, push, **ensure PR exists** (create only if none).

- AI-agnostic: any agent that edits files and runs `git`, `gh` or `glab`.
- Helpers: `skills/plan-implement-review/scripts/` (repo-root-relative). Each has `--help`.

## When to use

- "implement the plan", "build this", `/implement`
- Phase B of **plan-implement-review** (implementer)
- After `/write-plan`, when code is next

Not for: investigation with no code change; plan-only docs (`/write-plan`).

## 0. Inputs (resolve first)

| Input | Resolve |
|---|---|
| Plan path | User path, open PR plan file, or `docs/plans/YYYY/MM/*` matching topic |
| Asana / ticket | Fetch notes; map to plan or Concrete steps |
| Feature branch | See §1. Open plan/topic PR → **reuse its head branch**, don't rename. Fresh branch, no open plan PR → plan header `**Branch:**` as-is, or `fix/<topic>` / `feat/<topic>`. Never invent a parallel `fix/` branch that orphans a plan PR |
| Base | Always `origin/main` (or project default base) |

- Plan missing or steps ambiguous → **stop**, ask. Never invent scope.
- Tracker task → read its comments **before starting**; reuse plan/PR they point to. Format: [`tracker-comments.md`](../plan-implement-review/references/tracker-comments.md).

## 1. Git start (non-negotiable)

1. `skills/plan-implement-review/scripts/forge-ctx.sh` → `clean`, `branch`.
   - Not clean → **stop, ask** how to handle WIP before any checkout/pull.
   - Never stash, discard, or mix WIP into implement branch without approval.
2. `skills/plan-implement-review/scripts/pr-find.sh <planned-branch> <topic-token>` (planned branch per §0; token = kebab topic slug or task id). Verify returned title/URL before checkout. Act on `action`:
   - `reuse` → check out `head_pr.branch`, pull, implement there (add commits). No second PR.
   - `conflict` (exit 1) → same-topic PR on another head, e.g. plan-only.
     - **Preferred:** check out `topic_prs[0].branch`, implement there (plan + code, one PR).
     - Alt: branch from default, include plan commit, close plan-only PR as consolidated.
     - Never leave plan-only + fix both open.
   - `create` → `skills/plan-implement-review/scripts/fresh-branch.sh <feat-branch>` (fetches, branches from `origin/<default>`; exit 3 → stop).
3. Never implement on top of unrelated feature branch.

## 2. Implement

**Role** (PIR prompt `role=`; default `feature` when unset). Standalone `/implement` covers every role the plan names.

| `role` | Writes | Does not write |
| --- | --- | --- |
| `atdd` | Writer=`atdd` ATDD from outside the app (`system` + `api`: UI, API, contracts) | Product code, unit tests, plan-folder scripts |
| `script` | Plan sibling folder: `kinds.json`, `*.sh`, `evidence.md` | Product code, tests |
| `feature` | Product code and **unit** tests | Top-of-pyramid tests and plan-folder scripts when those roles exist |

Pyramid rows are observables, not internals ([pyramid](../verify-change/references/pyramid.md)). They should not change when implementation does. ATDD role may leave tests red until feature lands.

1. Follow plan **Concrete steps** in order. Stay inside **Out of scope**.
   - UI frame = pixel authority only if plan's Design source of truth marks it `exact`.
   - `partial` → follow agreed parts, ask on rest. `reference` → inspiration only ([figma-fidelity](../align/references/figma-fidelity.md)).
   - A screen follows [ui](../experimental/ui/ui.md): interaction, then craft, on top of that fidelity.
2. Grep/read before editing. Match project `AGENTS.md` / red lines (migrations immutable, no remote DB without approval, etc.).
   - Write to the repo's clean-code and other floors while editing (AGENTS.md guardrails, `.claude/rules/`). Analyzer, lint, docs lint, and git hooks fail the change on a miss. Fix the code; never disable the check.
   - Behavior change: load `tdd` when that skill is installed. Seams come from the plan. Skill absent → tests cover the public boundary the plan names, failing test first.
3. Run project checks until green, e.g. `npm run lint && npm run test` (or equivalent). Never disable tests/lint.
4. **Commits: approval + format**
   - `AGENTS.md` / `docs/rules/git-workflow.md` require approval → **propose message + diff, wait for explicit yes** before `git commit`. Skip only if user/PIR session pre-authorized implementer git writes for this run.
   - Format when `docs/rules/git-workflow.md` exists: `<branch-name>: 1. <change> 2. …` (numbered). Otherwise complete-sentence messages.
   - Commit **often**: one per significant green step. **Only** implement-related files (plus plan file if consolidating onto this branch).
5. **Push: less often, often never mid-PIR.**
   - Batch checkpoints locally. Don't push after every commit.
   - Push only when user/orchestrator asks, or at clear end milestone if pre-authorized.
   - Local commits serve recovery. "Implemented" needs no remote update until push requested.
6. **Prove it for reviewer.** If this PIR run's phases include `verify`, skip capture and skip writing the plan-folder recipe; atdd/script implementers and the verify phase own that. Otherwise follow [`verify-change`](../verify-change/verify-change.md).
   - No runtime behavior (docs, comments, rename, formatting): **no behavior change** line; no screenshots or scripts.
   - Screen look → before/after images. Behavior (click, type, motion, sequence) → short video. Backend → curl + HTTP file, response, trace or log. Database → read-only query + result. Deep change → diagram of path.
   - Before = base branch built from fresh clone in `/tmp/pir-<topic>/before/` (never feature branch). After = branch tip.
   - Captures → `/tmp/pir-<topic>/evidence/`, never in repo. Open every file: blank, error, or identical before/after frames = failed capture.
   - Attach on PR/MR. GitLab: `skills/implement/scripts/upload-evidence.mjs`. Comments carry prefix `🤖 _Posted by <AI assistant> (AI) on behalf of @<user>_`. Orchestrator posts unless run pre-authorized the implementer.
   - App can't run here → say so in PR, still leave Try it. Never skip silently.
   - Don't merge unless repo merge policy (`ai-risk`) lets an agent merge this tier.
   - Fill PR body Risk and Review guide sections.
7. **Remote rewritten under you.** `git push` rejected or `git fetch` shows `forced update` → never force-push:
   1. Backup branch.
   2. `git reset --hard origin/<branch>`.
   3. Cherry-pick your commits.
   4. Recheck, push as fast-forward.

## Budget

| Limit | Rule |
|---|---|
| Effort | `medium` default. `low` for mechanical plan (renames, docs, config, one file, no logic change). Never raise yourself. Two failed rounds → orchestrator |
| Context | 200k tokens per agent. Read only plan, files its steps name, test output tails. No whole-repo reads or full logs |
| Checkpoint | ~150k used, or rest of plan won't fit in 50k: commit green work, write `handoff.md` beside plan (done steps, next step, files touched, open problems), end turn |
| Next agent | Orchestrator starts fresh agent with plan + `handoff.md`. Never resume this one |
| Slices | Plan too large for one agent → parallel slices below. Each slice has own budget |

## Project AI (lead agent)

One background agent per repo: plans its slice, delegates to implementers. Orchestrator only aligns, reviews, gates.

| Use when | Skip when |
|---|---|
| Multi-repo → one project AI per repo | One repo, ≤ 3 plan steps |
| ≥ 3 parallel slices | Mechanical plan (low effort) |
| Plan + code won't fit one 200k budget | Orchestrator context has room |

- Project AI: `medium` effort. Runs `write-plan` for its repo, cuts slices, spawns implementers, merges, reports `{repo, branch, slices, status}`.
- Implementers report to their project AI, never orchestrator.
- Cross-repo contract (API, schema, event): orchestrator decides first. Project AIs never change it.

## Parallel slices (worktrees)

- Default: one implementer, one checkout.
- Isolated work (before-build, scratch runs) → fresh clone.
- Worktrees: allowed for any effort on one branch that splits into cleanly mergeable slices across worker agents (plan, fix list, port, sweep), not only PIR runs.

**When.** Work splits into ≥ 2 slices with disjoint owned paths, each earning its own agent, merging back without conflicts by construction. Else one implementer. Cap `max-slices` = 4 (override: `--max-slices`, `PIR_MAX_SLICES`).

| Situation | Do |
|---|---|
| Disjoint paths, same repo, base committed | Worktree per slice (below) |
| Disjoint paths, uncommitted base | Commit the base first (local commit, push later); never fork an uncommitted tree |
| Different repos | No worktree; one worker per repo |
| Paths overlap or slice B needs A's output | One worker, or sequence A → B |
| Shared tree without worktrees (emergency) | Only one worker stages/commits; others edit owned paths only |

- Judgment: planner/orchestrator names slices + owned paths in plan (`slices=` list; one `{name, paths[]}` each).
- Mechanical: `skills/implement/scripts/slices-check.sh SLICES.json` fails on bad names, count over cap, or overlapping path globs. Fix split, then continue.

**How.** Root = `${TMPDIR:-/tmp}/pir-<topic>/wt`, outside repo.
- Clone mode root: `${XDG_CACHE_HOME:-$HOME/.cache}/pir-<topic>/wt` (TMPDIR purge can't reach it).

1. Feature branch exists, tree clean (§1); uncommitted work → commit it as the base first.
2. `skills/implement/scripts/worktree-split.sh --base <feat> --topic <topic> --slices a,b,c` → branch `<feat>--<slice>` + checkout `<root>/<slice>` per slice, from feature tip. (`--`, not `/`: git can't hold `feat/x` and `feat/x/a` together.)
3. One subagent per checkout, prompt below. Subagents:
   - Edit only owned paths. Commit often on slice branch (§2.4 approval applies; PIR run pre-authorizes).
   - Never push, never leave checkout, never edit shared state (`state.json`, plan file).
   - Run slice lint/tests inside checkout.
4. When all report, orchestrator alone runs `skills/implement/scripts/worktree-merge.sh --into <feat> --topic <topic> --slices <ordered csv>` (`git merge --no-ff`; merge, never rebase). Order from plan or dependency. Script creates merge commits → needs same explicit approval as a commit in repos that gate commits. Git approval guard doesn't see git run inside scripts.
5. Conflict (exit 1, `conflict.files`) stops run. Report files, resolve by judgment, commit merge, merge `pending` slices.
6. Full regression gate + UI/proof evidence (§2.6) run **once**, on integrated feature branch.
7. Push and PR only from feature branch (§3).

**Cleanup is mandatory**: success, abort, failure alike, before phase reports done.
- `skills/implement/scripts/worktree-clean.sh --topic <topic>` removes checkouts, deletes merged slice branches, prunes, checks count.
  - Acts only on slices in `manifest.json` or registered under root in `git worktree list` (clone mode: clones whose origin is this repo). Anything else → `skipped[]`, left alone.
  - Failed `git status` counts as dirty.
- Result: `git worktree list` shows main checkout only. Report states it (`worktrees_left: 0`).
- Unmerged slice commits, uncommitted changes, or skipped slices block cleanup (`kept[]`/`skipped[]`, exit 1). List them to human. `--force` discards them; use only on human decision.

**Fallback `--mode clone`.** Use when repo `AGENTS.md`/`CLAUDE.md` forbids worktrees (search both for a worktree ban) or `git worktree` fails.
- One local clone per slice at `<root>/<slice>`.
- `worktree-merge.sh --mode clone` first fetches each slice branch (forced, so reruns after amend/reset work) into `refs/pir/<topic>/<slice>`.
- Cleanup: `worktree-clean.sh --mode clone`. Everything else identical.

**Slice subagent prompt (minimum).**

```text
Repo: <main checkout path>      Checkout: <root>/<slice>      Branch: <feat>--<slice>
Owned paths: <globs>            Plan section: <path#heading>
Work only in your checkout and only in owned paths. Commit often on your branch.
Do not push. Do not leave your checkout. Do not edit state files or the plan.
Report: changed files, slice test/lint result, anything outside your paths you needed.
```

## 3. PR: check before create (never open a second PR)

Re-run `skills/plan-implement-review/scripts/pr-find.sh "$(git branch --show-current)" <topic-token>` (state may have changed since §1). Act on `action`:

- `reuse` → push there. Refresh title/body when plan-only became code (`gh pr edit` / `glab mr update`).
- `conflict` (exit 1) → wrong head for same topic. Implement on that head. Do NOT create.
- `create` → if `AGENTS.md` / git-workflow require approval, propose title/body and wait. Then `gh pr create --base <default>` / `glab mr create`.

Rules:
- One PR per head branch, per task/topic/plan file. Prefer **one PR** with plan doc + implementation.
- Body: [`verify-change` template](../verify-change/assets/pr-body.md), plus plan link or path.

## 4. Done criteria

- [ ] Plan steps implemented (or explicit gaps listed); role=`atdd`/`script` only their rows
- [ ] Lint/tests green (feature). Top-of-pyramid tests may stay red on the atdd slice until feature merges
- [ ] Slices used: all merged, `worktree-clean.sh` ran, `git worktree list` = main checkout only (stated in report)
- [ ] Pushed (after approval when required)
- [ ] **Exactly one** open PR for this work; URL reported
- [ ] PR/MR description has Build, Proof, Try it from `verify-change` for the kinds this change needs (or a **no behavior change** line when it has none)
- [ ] **Tracker comment** if from a task: one **Implement rN** milestone after the round (PR link + human action if any). Format: [`tracker-comments.md`](../plan-implement-review/references/tracker-comments.md). Comments only, never otherwise edit the task

## Integration with plan-implement-review

As **implementer** inside `/plan-implement-review`:

1. Read plan path + branch from `/tmp/pir-<topic>/state.json` or orchestrator prompt.
2. Run this skill fully: git start → implement → ensure PR → tracker comment if from a task.
3. **PIR pre-authorization:** parent run typically authorizes feature-branch commit/push/PR for implementer this session. Never force-push, touch remote DB, or open second PR for same topic.
4. Write/update `state.json`: `feat_branch`, `implement_pr`, `session_id` if applicable.
5. Don't start a plan PR. Attach to existing plan branch/PR.

## Anti-patterns

- Implementing without reading plan, or inventing extra scope
- Branching from dirty feature branch instead of `origin/main` or existing ticket PR branch
- Stashing/discarding WIP without asking
- Creating `fix/<topic>` when open `plan/<topic>` PR exists for same work
- `gh pr create` when a PR already exists for this branch or same Asana topic
- Plan-only PR **and** separate implement PR both left open for same work
- Silent commit/push/PR when project rules require approval and no session pre-auth
- Disabling tests/lint to get green
- Worktrees outside parallel slices, inside repo dir, or left behind after phase; slices with overlapping owned paths; slice agents that push or merge
- Force-push / remote DB / migration edits against project red lines without explicit approval
- Skipping tracker comments when work came from a task, posting per command, or editing task beyond a comment
