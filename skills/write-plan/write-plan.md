---
name: write-plan
description: Write one durable plan markdown doc, then commit/push/ensure a PR exists. Use when the user asks to "make a plan", "write a plan doc", or /write-plan, before multi-step work that should leave a durable record, or as the plan-builder phase of plan-implement-review.
argument-hint: "[topic or task to plan]"
---

# Write-plan

Write one plan markdown file, then **commit, push, and ensure a PR exists** (create only if none already). That full sequence is “done” — not an optional follow-up.

AI-agnostic: any agent that can edit files, run git, and run `gh` can execute this.

## When to use

- User asks to “make a plan”, “write a plan doc”, `/write-plan`
- Before multi-step work that should leave a durable record
- Phase A of **plan-implement-review** (plan builder role)

Do **not** use for one-off bug fixes or already-finished work.

## Tracker comments

If this work came from a **tracker task** (e.g. Asana), follow [`../plan-implement-review/references/tracker-comments.md`](../plan-implement-review/references/tracker-comments.md) — canonical format/rules; do not copy them here.

- Read existing comments **before** writing. If they already point at a plan/PR for this task, reuse it instead of starting over (that overrides “always a new branch” in §0).
- After the plan PR exists, post **one Plan** comment. No task, no comments.

## 0. Always start from fresh latest main (non-negotiable)

**Before writing any plan file**, leave the current feature branch and start clean. **Exception:** if tracker comments already point at a plan/PR for this task, reuse that head — see Tracker comments above.

1. Note uncommitted work on the current branch — do **not** mix it into the plan branch.
2. `git fetch origin main` (or project default base, usually `main`).
3. Create and check out a **new** plan branch from **`origin/main` only**:
   ```bash
   git checkout -b <branch-name> origin/main
   ```
   Prefer plan header `**Branch:**` (e.g. `plan/<topic>`).  
   **Never** branch from the currently checked-out feature branch.  
   **Never** write the plan on top of feature-branch commits.
4. Only after that checkout: write the plan under `docs/plans/…`.

If fetch fails, stop and tell the user — do not invent a base.

## 1. Write the file

- Location: `docs/plans/<YYYY>/<MM>/` (create month folder if missing). If the repo has no `docs/plans/`, match the repo’s existing convention — do not invent a third pattern.
- Filename: `YYYY-MM-DD_kebab-case-topic.md` (real current date).
- Mirror structure of existing files in that folder. Floor:
  - Header: title, **Date**, **Branch**, **Status**
  - Context
  - Why this approach
  - Concrete steps
  - Out of scope
  - Manual verification / test checklist when useful
- Every file/symbol/table/route named must be grepped/confirmed first. If unsure, say so in the plan — do not invent paths.
- Dense: tables over prose; no filler.

## 2. Commit, push, PR

1. Confirm still on the plan branch from §0 (base = `origin/main`, only plan commits).  
   If an **open PR already exists for this topic/plan**, prefer that PR’s **head branch**
   (checkout + push there) instead of a brand-new branch.
2. Commit **only** the plan file(s). Check `git status` first — do not sweep unrelated dirt.
3. Push with `-u`.
4. **PR — ALWAYS check before create. Never open a second PR for the same work.**

   Run **both** checks; only create when **both** are empty:

   ```bash
   branch=$(git branch --show-current)
   plan_file="YYYY-MM-DD_kebab-case-topic.md"   # the file you just wrote

   # 1) Open PR already from this head?
   existing=$(gh pr list --head "$branch" --base main --state open \
     --json url -q '.[0].url')

   # 2) Open PR for same plan filename / topic (any head)?
   topic_pr=$(gh pr list --search "$plan_file" --state open \
     --json url,headRefName,title -q '.[0].url')
   # If empty, also search a short topic slug / Asana gid from the plan header.

   if [ -n "$existing" ]; then
     # Reuse — optionally refresh title/body: gh pr edit --title "…" --body "…"
     echo "$existing"
   elif [ -n "$topic_pr" ]; then
     # Same work already has a PR on another head — DO NOT create another.
     # Checkout that head and land the plan there, or stop and report topic_pr.
     echo "Same-topic PR already open: $topic_pr — reuse that head; do not gh pr create"
     exit 1
   else
     gh pr create --draft --base main
     # short title; body = plan summary + test-plan checklist from Concrete steps
   fi
   ```

   **Rules:**
   - Never `gh pr create` until both checks above are empty.
   - Never open a second PR for the same head branch.
   - Never open a second PR for the same plan file / Asana / topic when one is already open.
   - Prefer **one** PR that can later hold plan + implementation (not plan-only + fix).
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
- **`gh pr create` without first checking** `--head` **and** same-topic/plan-filename open PRs
- Opening a **new** PR when one already exists for the same head branch / same Asana topic / same plan file
- Plan-only PR **and** separate implementation PR for the same work when one PR can hold both
- Plan file without any PR when the skill was asked for a durable plan (and none exists yet)
- Asserting code locations without verification
- Implementing the plan in the same turn unless user asked for the full loop

## Related

- Sibling skill [`implement`](../implement/implement.md) (`/implement`) — code the plan; same one-PR rules.
- [`plan-implement-review`](../plan-implement-review/plan-implement-review.md) — full loop.
