---
name: write-plan
description: Write one durable plan markdown doc, then commit/push/ensure a PR exists. Use when the user asks to "make a plan", "write a plan doc", or /write-plan, before multi-step work that should leave a durable record, or as the plan-builder phase of plan-implement-review.
argument-hint: "[topic or task to plan] [align=<path>]"
---

# Write-plan

Write one plan markdown file, then **commit, push, and ensure a PR exists** (create only if none already). That full sequence is “done” — not an optional follow-up.

AI-agnostic: any agent that can edit files and run git, `gh` or `glab` can execute this. Helper scripts live in `skills/plan-implement-review/scripts/` (repo-root-relative); each has `--help`.

## When to use

- User asks to “make a plan”, “write a plan doc”, `/write-plan`
- Before multi-step work that should leave a durable record
- Phase A of **plan-implement-review** (plan builder role)

Do **not** use for one-off bug fixes or already-finished work.

## Tracker comments

If this work came from a **tracker task** (e.g. Asana), follow [`../plan-implement-review/references/tracker-comments.md`](../plan-implement-review/references/tracker-comments.md) — canonical format/rules; do not copy them here.

- Read existing comments **before** writing. If they already point at a plan/PR for this task, reuse it instead of starting over (that overrides “always a new branch” in §0).
- After the plan PR exists, post **one Plan** comment. No task, no comments.

## Align first

1. `skills/align/scripts/assess.sh "<task>"` (absent → skip this step). `suggest_align` true → say why in one line (`reasons`) and offer [`align`](../align/align.md). Never block. Declined → write "align skipped by user" in Context.
   Plan spans repos or ≥ 3 slices → write `Lead: project AI per repo` in Context ([implement §Project AI](../implement/implement.md)).
2. An align dir exists (`docs/align/<topic>/`, or `align=<path>`): `spec.md` is the scope source. Fold the spec, ADRs and glossary into the plan once (Terms, Decisions, Acceptance criteria sections); never commit or link the align dir. `(non-blocking)` open questions go in Risks. `Aligned: no` or a `(blocking)` question → stop and ask.
3. `ui` true: before planning, ask once for the Figma link(s) (none given → plan from the repo's design system and say so) and run [figma-fidelity](../align/references/figma-fidelity.md). The plan carries its **Design source of truth** table; the implementer and reviewer treat only `exact` frames as pixel-authority.

## Discover first (discovery and technical-planning tasks)

Applies when the ticket type is Discovery or Technical Planning, or the user says the plan starts from unknowns. Skip it when scope is already known.

1. Run [`discover`](../discover/SKILL.md) on the ticket's question. Targets: the repos and forge projects the ticket names, else inferred. One wave, at most 8 scouts; the forge slice stays optional. Read-only; it writes nothing.
2. Take its output into the plan:
   - **Answer** and **Corrections** feed Context and Why this approach.
   - **Gaps** become concrete steps or open questions in the plan.
   - **Evidence** keeps its `path:line` citations. Unverified items stay marked unverified.
   - **Read from** (refs and shas) goes in the Context header.
3. No scout transcripts in the plan. An agent that cannot spawn subagents reads the named targets itself, from the latest default branch.

## 0. Always start from fresh latest main (non-negotiable)

**Before writing any plan file**, leave the current feature branch and start clean. **Exception:** if tracker comments already point at a plan/PR for this task, reuse that head — see Tracker comments above.

1. Uncommitted work on the current branch: never mix it into the plan branch. Exception: an untracked align dir moves aside, then back after the branch exists; it stays uncommitted.
2. `skills/plan-implement-review/scripts/fresh-branch.sh <branch-name>` — fetches, then creates the branch from `origin/<default>` only. Prefer plan header `**Branch:**` (e.g. `plan/<topic>`).
   - Exit 3 (dirty tree, fetch failed, branch exists) → stop and tell the user. Never invent a base, never stash.
   - **Never** branch from, or write the plan on top of, feature-branch commits.
3. Only after that: write the plan under `docs/plans/…`.

## 1. Write the file

- Location: `docs/plans/<YYYY>/<MM>/` (create month folder if missing). If the repo has no `docs/plans/`, match the repo’s existing convention — do not invent a third pattern.
- Filename: `YYYY-MM-DD_kebab-case-topic.md` (real current date).
- Mirror structure of existing files in that folder. Floor:
  - Header: title, **Date**, **Branch**, **Status**
  - Context
  - Why this approach
  - Concrete steps
  - Risks (open non-blocking align questions)
  - Design source of truth (UI work)
  - Monitoring plan (monitored runs; §1a)
  - Out of scope
  - Manual verification / test checklist when useful
- Every file/symbol/table/route named must be grepped/confirmed first. If unsure, say so in the plan — do not invent paths.
- Dense: tables over prose; no filler.

## 1a. Monitoring plan (changes that deploy)

A run whose phases include `monitor` (`apirwm`, `m`, `phases=…,monitor`), or a user who asks for one, carries a **Monitoring plan** section; otherwise offer it in one line for a change that deploys and move on. Build it from [`monitoring-plan.md`](../monitor/assets/templates/monitoring-plan.md); `skills/monitor/scripts/check-plan.sh <plan>` exits 0.

- Signals derive from the acceptance criteria (align spec `AC-n` ids when present); every criterion maps to a signal
- Baseline captured **before** deploy: name when and how (query, time range)
- Each signal names a failure action and an owner
- Docs-only or test-only change: write `No runtime change: monitoring skipped.`

## 2. Commit, push, PR

1. Confirm still on the plan branch from §0 (base = `origin/main`, only plan commits).  
   If an **open PR already exists for this topic/plan**, prefer that PR’s **head branch**
   (checkout + push there) instead of a brand-new branch.
2. Commit **only** the plan file(s), never the align dir. Check `git status` first — do not sweep unrelated dirt.
3. Push with `-u`.
4. **PR — check before create. Never open a second PR for the same work.**
   `skills/plan-implement-review/scripts/pr-find.sh <branch> <topic-token>` (token = kebab topic slug or task id; read-only). Act on `action`:
   - `reuse` → push to `head_pr`; optionally refresh title/body (`gh pr edit` / `glab mr update`).
   - `conflict` (exit 1) → same-topic PR on another head (`topic_prs`): check out that head and land the plan there, or stop and report it. Never create.
   - `create` → open a **draft** PR/MR against the default branch (`gh pr create --draft` / `glab mr create --draft`): short title; body = plan summary + test-plan checklist from Concrete steps.
   - One PR per head branch, per plan file, per task. Prefer **one** PR that later holds plan + implementation (not plan-only + fix).
5. Report the PR URL as the final output (and to parent skill state if running inside plan-implement-review). If a tracker task originated this work, post the Plan comment (see Tracker comments).

## Integration with plan-implement-review

When invoked as the **plan builder** inside `/plan-implement-review`:

1. Run this skill fully (fresh main → file + draft PR).
2. Write into `/tmp/pir-<topic>/state.json`:
   - `plan_path`, `plan_branch`, `plan_pr`, `topic`
3. Hand off to implement phase (do not implement unless user said plan-only is false / full loop).

If `plan-builder=self`, the orchestrator agent runs these steps itself.  
If `plan-builder=<profile-id>`, spawn that profile with this file as instructions + the user task.

## Anti-patterns

- Starting a new plan when tracker comments already point at a plan/PR for this task
- Writing a plan while still on a feature branch / stacking on feature commits
- Creating a PR without `pr-find.sh` saying `create`
- Opening a **new** PR when one already exists for the same head branch / same Asana topic / same plan file
- Plan-only PR **and** separate implementation PR for the same work when one PR can hold both
- Plan file without any PR when the skill was asked for a durable plan (and none exists yet)
- Asserting code locations without verification
- Implementing the plan in the same turn unless user asked for the full loop
- Planning a discovery or technical-planning ticket from memory or a stale checkout when `discover` could gather the context first
- Coding against a design frame whose fidelity nobody confirmed
- A monitored run with no Monitoring plan, or a baseline first captured after the deploy

## Related

- Sibling skill [`implement`](../implement/implement.md) (`/implement`) — code the plan; same one-PR rules.
- [`plan-implement-review`](../plan-implement-review/plan-implement-review.md) — full loop.
- [`discover`](../discover/SKILL.md) — parallel scouts for the context a discovery or technical-planning plan starts from.
- [`align`](../align/align.md) — spec, ADRs and glossary this plan folds in; [figma-fidelity](../align/references/figma-fidelity.md) — design frame check.
- [`monitor`](../monitor/monitor.md) — runs the Monitoring plan after the PROD deploy.
