---
name: write-plan
description: Write one durable plan markdown doc, then commit/push/ensure a PR exists. Use when the user asks to "make a plan", "write a plan doc", or /write-plan, before multi-step work that should leave a durable record, or as the plan-builder phase of plan-implement-review.
argument-hint: "[topic or task to plan] [align=<path>]"
---

# Write-plan

Write one plan markdown file, then **commit, push, and ensure a PR exists** (create only if none). That full sequence is done. Not an optional follow-up.

AI-agnostic: any agent that can edit files and run git, `gh` or `glab`. Helpers: `skills/plan-implement-review/scripts/` (repo-root-relative); each has `--help`.

## When to use

- User asks to "make a plan", "write a plan doc", `/write-plan`
- Before multi-step work that should leave a durable record
- Phase A of **plan-implement-review** (plan builder role)

Not for one-off bug fixes or already-finished work.

## Tracker comments

Work from a **tracker task** (e.g. Asana): follow [`../plan-implement-review/references/tracker-comments.md`](../plan-implement-review/references/tracker-comments.md). It is canonical; do not copy it here.

- Read existing comments **before** writing. If they already point at a plan/PR for this task, reuse it (overrides "always a new branch" in §0)
- After the plan PR exists, post **one Plan** comment. No task, no comments

## Align first

1. `skills/align/scripts/assess.sh "<task>"` (absent → skip). `suggest_align` true → say why in one line (`reasons`), offer [`align`](../align/align.md). Never block. Declined → write "align skipped by user" in Context
   - Plan spans repos or ≥3 slices → Context: `Lead: project AI per repo` ([implement §Project AI](../implement/implement.md))
2. Align dir exists (`docs/align/<topic>/`, or `align=<path>`): `spec.md` is the scope source. Fold spec, ADRs, glossary into the plan once (Terms, Decisions, Acceptance criteria sections). Never commit or link the align dir. `(non-blocking)` open questions → Risks. `Aligned: no` or a `(blocking)` question → stop and ask
3. `ui` true: before planning, ask once for Figma link(s) (none → plan from the repo's design system, say so) and run [figma-fidelity](../align/references/figma-fidelity.md). Plan carries its **Design source of truth** table; implementer and reviewer treat only `exact` frames as pixel-authority. Also name the job, the primary action, and empty, loading, error, and success ([ui](../experimental/ui/ui.md))

## Discover first (Discovery and Technical Planning tasks)

Applies when ticket type is Discovery or Technical Planning, or user says the plan starts from unknowns. Skip when scope is known.

1. Run [`discover`](../discover/SKILL.md) on the ticket's question. Targets: repos and forge projects the ticket names, else inferred. One wave, ≤8 scouts; forge slice optional. Read-only; writes nothing
2. Output into the plan:
   - **Answer**, **Corrections** → Context, Why this approach
   - **Gaps** → concrete steps or open questions
   - **Evidence** keeps `path:line` citations; unverified items stay marked unverified
   - **Read from** (refs, shas) → Context header
3. No scout transcripts in the plan. An agent that cannot spawn subagents reads the named targets itself, from the latest default branch

## Planner host (lead agent)

Any host that can plan, write the plan file, then delegate to implementers can run this skill as the lead ([implement §Project AI](../implement/implement.md)). The plan file in the repo is the contract; host-native plan stores are drafts.

| Host | Plan surface | Delegation |
|---|---|---|
| Cursor | Projects (inner loop); Plan mode writes Markdown plans | async, nestable subagents; `/worktree`, CLI `--worktree` |
| Claude Code | plan mode; plan written to a file on request | subagents (Agent tool), background agents, worktrees |
| OpenAI Codex | plan in the task before edits | parallel cloud tasks, one sandbox each |
| Google Jules | plan shown for approval before coding | async tasks in cloud VMs |
| Other / unknown | ask the agent to write the plan file | separate background process per implementer |

- Host plan store (e.g. `.cursor/plans/`) → copy the final plan to this skill's path; never leave the only copy there
- Not verified from primary docs: Cursor Projects internals, Codex and Jules plan-file output. Check the host's docs before relying on them
- Meta: no planner-delegator agent product known; use Other

## 0. Always start from fresh latest main (non-negotiable)

Before writing any plan file, leave the current feature branch and start clean. **Exception:** tracker comments already point at a plan/PR for this task → reuse that head (see Tracker comments).

1. Uncommitted work on the current branch: never mix into the plan branch. Exception: an untracked align dir moves aside, then back once the branch exists; it stays uncommitted
2. `skills/plan-implement-review/scripts/fresh-branch.sh <branch-name>`: fetches, creates the branch from `origin/<default>` only. Prefer plan header `**Branch:**` (e.g. `plan/<topic>`)
   - Exit 3 (dirty tree, fetch failed, branch exists) → stop, tell the user. Never invent a base. Never stash
   - **Never** branch from, or write the plan on top of, feature-branch commits
3. Only then: write the plan under `docs/plans/…`

## 1. Write the file

- Location: `docs/plans/<YYYY>/<MM>/` (create month folder if missing). No `docs/plans/` → match the repo's existing convention; do not invent a third pattern
- Filename: `YYYY-MM-DD_kebab-case-topic.md` (real current date)
- Verify may add a sibling folder named like the plan file (no `.md`) for scripts and a short evidence index. Omit it when the change has no product evidence
- Mirror the structure of existing files in that folder. Floor:
  - Header: title, **Date**, **Branch**, **Status**
  - Context
  - Why this approach
  - Concrete steps
  - Risks (open non-blocking align questions)
  - Design source of truth (UI work)
  - Monitoring plan (monitored runs; §1a)
  - Verification (pyramid: system + api only; §1b)
  - Out of scope
- Grep or confirm every file, symbol, table, or route named. Unsure → say so in the plan. Never invent paths
- Dense: tables over prose; no filler

## 1a. Monitoring plan (changes that deploy)

A run whose phases include `monitor` (`apirwm`, `m`, `phases=…,monitor`), or a user who asks for one, carries a **Monitoring plan** section. Otherwise offer it in one line for a change that deploys, and move on. Build from [`monitoring-plan.md`](../monitor/assets/templates/monitoring-plan.md); `skills/monitor/scripts/check-plan.sh <plan>` exits 0.

- Signals derive from acceptance criteria (align spec `AC-n` ids when present). Every criterion maps to a signal
- Baseline captured **before** deploy: name when and how (query, time range)
- Each signal names a failure action and an owner
- Docs-only or test-only change: write `No runtime change: monitoring skipped.`

## 1b. Verification pyramid

Runtime change: a **Verification** section. Contract for test and script implementers. Observables the human agreed in align or in this plan. Implementation under them may change; these rows should not. Unit tests stay out.

`skills/verify-change/scripts/check-pyramid.sh <plan>` exits 0. Shape: [pyramid](../verify-change/references/pyramid.md).

| Layer | What | Cases | Writer |
| --- | --- | --- | --- |
| system | UI, REST, or other in-system observable | happy and critical only, few | `test` |
| api | Talks to the app; no external services | happy and critical only, few | `test` |
| (script rows) | Same observables as a shell recipe | happy and critical only, few | `script` |

Each row: Layer, Cases, AC, Observable, Writer. Observable is what a person or API caller sees ("user clicks Save and the row appears", "POST /items creates an item"). Align spec **Verification** folds in here with the acceptance criteria.

No runtime: `No runtime change: pyramid skipped.` under **Verification**.

## 2. Commit, push, PR

1. Confirm still on the plan branch from §0 (base = `origin/main`, only plan commits). If an **open PR already exists for this topic/plan**, prefer that PR's **head branch** (checkout + push there) over a brand-new branch
2. Commit **only** the plan file(s), never the align dir. `git status` first. Do not sweep unrelated dirt
3. Push with `-u`
4. **PR: check before create. Never open a second PR for the same work.** `skills/plan-implement-review/scripts/pr-find.sh <branch> <topic-token>` (token = kebab topic slug or task id; read-only). Act on `action`:
   - `reuse` → push to `head_pr`; optionally refresh title/body (`gh pr edit` / `glab mr update`)
   - `conflict` (exit 1) → same-topic PR on another head (`topic_prs`): check out that head and land the plan there, or stop and report. Never create
   - `create` → open a **draft** PR/MR against the default branch (`gh pr create --draft` / `glab mr create --draft`). Short title; body = plan summary + Verification rows from §1b
   - One PR per head branch, per plan file, per task. Prefer **one** PR that later holds plan + implementation (not plan-only + fix)
5. Report the PR URL as the final output (and to parent skill state if inside plan-implement-review). Tracker task origin → post the Plan comment (see Tracker comments)

## Integration with plan-implement-review

Plan builder inside `/plan-implement-review`:

1. Run this skill fully (fresh main → file + draft PR)
2. Write `/tmp/pir-<topic>/state.json`: `plan_path`, `plan_branch`, `plan_pr`, `topic`
3. Hand off to implement. Do not implement unless user said plan-only is false (full loop)

`plan-builder=self`: orchestrator agent runs these steps itself. `plan-builder=<profile-id>`: spawn that profile with this file as instructions + user task.

## Anti-patterns

- Starting a new plan when tracker comments already point at a plan/PR for this task
- Writing a plan while on a feature branch / stacking on feature commits
- Creating a PR without `pr-find.sh` saying `create`
- Opening a second PR for the same head branch, same Asana topic, or same plan file
- Plan-only PR **and** separate implementation PR when one PR can hold both
- Plan file with no PR when a durable plan was asked for (and none exists yet)
- Asserting code locations without verification
- Implementing the plan in the same turn unless the user asked for the full loop
- Planning a discovery or technical-planning ticket from memory or a stale checkout when `discover` could gather context first
- Coding against a design frame whose fidelity nobody confirmed
- Monitored run with no Monitoring plan, or baseline first captured after the deploy

## Related

- Sibling skill [`implement`](../implement/implement.md) (`/implement`): codes the plan; same one-PR rules
- [`plan-implement-review`](../plan-implement-review/plan-implement-review.md): full loop
- [`discover`](../discover/SKILL.md): parallel scouts for the context a discovery or technical-planning plan starts from
- [`align`](../align/align.md): spec, ADRs, glossary this plan folds in; [figma-fidelity](../align/references/figma-fidelity.md): design frame check
- [`monitor`](../monitor/monitor.md): runs the Monitoring plan after the PROD deploy
