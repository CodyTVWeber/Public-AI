---
name: implement
description: Implement work from a plan file, ticket, or explicit fix list - code, lint/test green, commit, push, ensure a PR exists. Use when the user says "implement the plan", "build this", /implement, or as the implementer phase of plan-implement-review.
argument-hint: "[plan path or ticket]"
---

# Implement

Implement work from a **plan file**, Asana task, or explicit user fix list: code, lint/test green, commit, push, and **ensure a PR exists** (create only if none already).

AI-agnostic: any agent that can edit files and run git, `gh` or `glab` can execute this. Helper scripts live in `skills/plan-implement-review/scripts/` (repo-root-relative); each has `--help`.

## When to use

- User says “implement the plan”, “build this”, `/implement`
- Phase B of **plan-implement-review** (implementer role)
- After `/write-plan` when the user wants the code next

Do **not** use for pure investigation with no code change, or for plan-only docs (use `/write-plan`).

## 0. Inputs (resolve first)

| Input | How to resolve |
|-------|----------------|
| Plan path | User path, open PR plan file, or latest `docs/plans/YYYY/MM/*` for the topic |
| Asana / ticket | Fetch notes; map to plan or Concrete steps |
| Feature branch | See §1. If an **open plan/topic PR** exists, **reuse its head branch** (do not rename). Only when creating a fresh branch with no open plan PR: use plan header `**Branch:**` as-is, or `fix/<topic>` / `feat/<topic>`. Do **not** invent a parallel `fix/` branch that orphans a plan PR. |
| Base | Always **`origin/main`** (or project default base) |

If the plan is missing or steps are ambiguous, **stop** and ask — do not invent scope.

If this work came from a **tracker task**, read that task’s comments **before starting**. Reuse any plan/PR they already point to. Comment format: [`../plan-implement-review/references/tracker-comments.md`](../plan-implement-review/references/tracker-comments.md).

## 1. Git start (non-negotiable)

1. `skills/plan-implement-review/scripts/forge-ctx.sh` → `clean`, `branch`. Not clean: **stop and ask** the user how to handle WIP before any checkout/pull. Never stash, discard, or mix WIP into the implement branch without approval.
2. `skills/plan-implement-review/scripts/pr-find.sh <planned-branch> <topic-token>` (planned branch per §0; token = kebab topic slug or task id). Verify the returned title/URL before checkout. Act on `action`:
   - `reuse` → check out `head_pr.branch`, pull, implement there (add commits). No second PR.
   - `conflict` (exit 1) → same-topic PR on another head, e.g. plan-only. **Preferred:** check out `topic_prs[0].branch` and implement on it (plan + code, one PR). Alternative: branch from the default branch, include the plan commit, then close the plan-only PR as consolidated. Never leave plan-only + fix both open.
   - `create` → `skills/plan-implement-review/scripts/fresh-branch.sh <feat-branch>` (fetches, branches from `origin/<default>`; exit 3 → stop).
3. Never implement on top of an unrelated feature branch.

## 2. Implement

1. Follow the plan’s **Concrete steps** in order; stay inside **Out of scope**.
2. Grep/read before editing; match project `AGENTS.md` / red lines (migrations immutable, no remote DB without approval, etc.).
3. Run project checks until green, e.g. `npm run lint && npm run test` (or project equivalent). Do not disable tests/lint.
4. **Commits — approval + format:**
   - If `AGENTS.md` / `docs/rules/git-workflow.md` require approval: **propose message + diff and wait for explicit yes** before `git commit` (unless the user/PIR session already pre-authorized implementer git writes for this run).
   - Message format when `docs/rules/git-workflow.md` exists: **`<branch-name>: 1. <change> 2. …`** (numbered list). Otherwise complete-sentence messages.
   - Commit **often** (one checkpoint per significant green step). **Only** implement-related files (and the plan file if consolidating onto this branch).
5. **Push — less often (often never mid-PIR):** Batch checkpoint commits locally. **Do not push** after every commit. Push only when the user/orchestrator asks, or at a clear end milestone if pre-authorized. Prefer local commits for recovery; remote update is not required to claim “implemented” until push is requested.
6. **Prove it for the reviewer.** Follow [`verify-change`](../verify-change/verify-change.md). The PR/MR body uses that skill's template: what changed, build, proof, and Try it steps a person can paste.
   - Look of a screen: before/after images. Behavior (click, type, motion, a sequence): a short video. Backend: curl plus an HTTP file, the response, and a trace or log. Database: a read-only query and its result. A deep change: a diagram of the path.
   - Before = the base branch built from a fresh clone in `/tmp/pir-<topic>/before/` (never the feature branch). After = branch tip. Save captures to `/tmp/pir-<topic>/evidence/`, never into the repo. Open every file: blank, error, or identical before/after frames = failed capture.
   - Attach on the PR/MR. GitLab: `skills/implement/scripts/upload-evidence.py`. Comments carry an attribution prefix (`🤖 _Posted by <AI assistant> (AI) on behalf of @<user>_`). Orchestrator posts unless the run pre-authorized the implementer.
   - App can't run here → say so in the PR and still leave Try it. Never skip silently. Do not merge unless the repo's merge policy (`ai-risk`) lets an agent merge this tier. Fill the PR body's Risk and Review guide sections.
7. **Remote rewritten under you.** `git push` rejected or `git fetch` shows `forced update` → never force-push. Make a backup branch, `git reset --hard origin/<branch>`, cherry-pick your new commits, recheck, push as fast-forward.

## 3. PR — check before create (never open a second PR)

Re-run `skills/plan-implement-review/scripts/pr-find.sh "$(git branch --show-current)" <topic-token>` (state may have changed since §1). Act on `action`:

- `reuse` → push there; refresh title/body when plan-only became code (`gh pr edit` / `glab mr update`).
- `conflict` (exit 1) → wrong head for the same topic: implement on that head instead; do NOT create.
- `create` → if `AGENTS.md` / git-workflow require approval, propose title/body and wait; then `gh pr create --base <default>` / `glab mr create`.

**Rules:**

- One PR per head branch, per task/topic/plan file. Prefer **one PR** containing plan doc + implementation.
- Body: [`verify-change` template](../verify-change/assets/pr-body.md), plus the plan link or path.

## 4. Done criteria

- [ ] Plan steps implemented (or explicit gaps listed)
- [ ] Lint/tests green
- [ ] Pushed (after approval when required)
- [ ] **Exactly one** open PR for this work; URL reported
- [ ] PR/MR description has Build, Proof, and Try it from `verify-change`, including images for look, video for behavior, and curl, log, or query for backend and database
- [ ] **Tracker comment** if this work came from a task: one **Implement rN** milestone comment after the round (PR link + human action if any). Format in [`tracker-comments.md`](../plan-implement-review/references/tracker-comments.md). Comments only — never otherwise edit the task.

## Integration with plan-implement-review

When invoked as the **implementer** inside `/plan-implement-review`:

1. Read plan path + branch from `/tmp/pir-<topic>/state.json` or the orchestrator prompt.
2. Run this skill fully (git start → implement → ensure PR → tracker comment if the work came from a task).
3. **PIR pre-authorization:** the parent `/plan-implement-review` run typically authorizes feature-branch commit/push/PR for the implementer for that session — still never force-push, never remote DB, never second PR for same topic.
4. Write/update `state.json`: `feat_branch`, `implement_pr`, `session_id` if applicable.
5. Do not start a new plan PR; attach to existing plan branch/PR when present.

## Anti-patterns

- Implementing without reading the plan / inventing extra scope
- Branching from a dirty feature branch instead of `origin/main` or the existing ticket PR branch
- Stashing/discarding WIP without asking
- Creating `fix/<topic>` when an open `plan/<topic>` PR already exists for the same work
- **`gh pr create` when a PR already exists** for this branch or same Asana topic
- Plan-only PR **and** separate implement PR left both open for the same work
- Silent commit/push/PR when project rules require approval and no session pre-auth
- Disabling tests/lint to get green
- Force-push / remote DB / migrations edits against project red lines without explicit approval
- Skipping tracker comments when the work came from a task, posting per command, or editing the task besides a comment
