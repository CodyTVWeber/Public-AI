---
name: implement
description: Implement work from a plan file, ticket, or explicit fix list - code, lint/test green, commit, push, ensure a PR exists. Use when the user says "implement the plan", "build this", /implement, or as the implementer phase of plan-implement-review.
argument-hint: "[plan path or ticket]"
---

# Implement

Implement work from a **plan file**, tracker task (e.g. Asana), or explicit user fix list: code, lint/test green, commit, push, and **ensure a PR exists** (create only if none already).

AI-agnostic: any agent that can edit files, run git, and run `gh` can execute this.

## When to use

- User says “implement the plan”, “build this”, `/implement`
- Phase B of **plan-implement-review** (implementer role)
- After `/write-plan` when the user wants the code next

Do **not** use for pure investigation with no code change, or for plan-only docs (use `/write-plan`).

## Tracker comments

If this work came from a **tracker task** (e.g. Asana), follow [`../plan-implement-review/references/tracker-comments.md`](../plan-implement-review/references/tracker-comments.md) — canonical format/rules; do not copy them here.

- Read existing comments **before** coding. Reuse a plan/PR they point to rather than opening a new one.
- After this implement round, post **one Implement rN** comment (r1, r2, …). No task, no comments.

## 0. Inputs (resolve first)

| Input | How to resolve |
|-------|----------------|
| Plan path | User path, open PR plan file, or latest `docs/plans/YYYY/MM/*` for the topic |
| Tracker task (e.g. Asana) | Fetch notes and comments; map to plan or Concrete steps |
| Feature branch | See §1. If an **open plan/topic PR** exists, **reuse its head branch** (do not rename). Only when creating a fresh branch with no open plan PR: use plan header `**Branch:**` as-is, or `fix/<topic>` / `feat/<topic>`. Do **not** invent a parallel `fix/` branch that orphans a plan PR. |
| Base | Always **`origin/main`** (or project default base) |

If the plan is missing or steps are ambiguous, **stop** and ask — do not invent scope.

## 1. Git start (non-negotiable)

1. **Dirty tree:** If `git status` shows uncommitted work (staged/unstaged/untracked that is not ignorable dirt), **stop and ask** the user how to handle WIP before `checkout` / `pull`. Do **not** stash, discard, or mix WIP into the implement branch without approval.
2. `git fetch origin main`
3. **Reuse vs create branch** (verify title/URL before checkout — do not trust the first search hit blindly):
   ```bash
   # Same-topic open PRs: prefer exact signals (Asana gid, plan filename) over broad keywords
   existing=$(gh pr list --search "<asana-gid OR plan-filename>" --state open \
     --json headRefName,url,title,body -q '.[0]')
   # Also list by known heads if you already have plan/ or fix/ names
   gh pr list --head "plan/<topic>" --state open --json url,headRefName
   gh pr list --head "fix/<topic>" --state open --json url,headRefName
   ```
   - If an **open PR already exists** for this work (same Asana / same plan / same topic): check out that **head** branch, pull, implement **there** (add commits). Do **not** open another PR.
   - Else if a **plan-only** branch/PR exists for the same topic:  
     (a) check out the plan branch and implement on it (plan + code, **one PR**) — **preferred**, or  
     (b) branch from `origin/main`, cherry-pick/include the plan commit, implement, one PR — then close the plan-only PR as consolidated.  
     Prefer (a). Never leave plan-only + fix as two long-lived open PRs for the same ticket.
   - Else: `git checkout -b <feat-branch> origin/main`
4. Never implement on top of an unrelated feature branch.

## 2. Implement

1. Follow the plan’s **Concrete steps** in order; stay inside **Out of scope**.
2. Grep/read before editing; match project `AGENTS.md` / red lines (migrations immutable, no remote DB without approval, etc.).
3. Run project checks until green, e.g. `npm run lint && npm run test` (or project equivalent). Do not disable tests/lint.
4. **Commits — approval + format:**
   - If `AGENTS.md` / `docs/rules/git-workflow.md` require approval: **propose message + diff and wait for explicit yes** before `git commit` (unless the user/PIR session already pre-authorized implementer git writes for this run).
   - Message format when `docs/rules/git-workflow.md` exists: **`<branch-name>: 1. <change> 2. …`** (numbered list). Otherwise complete-sentence messages.
   - Commit **often** (one checkpoint per significant green step). **Only** implement-related files (and the plan file if consolidating onto this branch).
5. **Push — less often (often never mid-PIR):** Batch checkpoint commits locally. **Do not push** after every commit. Push only when the user/orchestrator asks, or at a clear end milestone if pre-authorized. Prefer local commits for recovery; remote update is not required to claim “implemented” until push is requested.

## 3. PR — ALWAYS check before create (never open a second PR)

**Mandatory before any `gh pr create`:** re-check same-topic open PRs (not only current head).  
If either check returns a URL, **reuse that PR** — do not create.

```bash
branch=$(git branch --show-current)
# 1) This head
existing=$(gh pr list --head "$branch" --base main --state open --json url -q '.[0].url')
# 2) Same topic / Asana / plan filename (any head) — verify title/body match before reuse
topic_pr=$(gh pr list --search "<asana-gid OR plan-filename>" --state open \
  --json url,headRefName,title -q '.[0].url')
if [ -n "$existing" ]; then
  gh pr edit --title "…" --body "…"   # when plan-only → has code
  echo "$existing"
elif [ -n "$topic_pr" ]; then
  # Wrong head for same topic: checkout that head or consolidate — do NOT create a second PR
  echo "Same-topic PR already open: $topic_pr — implement on its head instead"
  exit 1
else
  # Approval: if AGENTS/git-workflow require it, propose title/body and wait before gh pr create
  gh pr create --base main --title "…" --body "…"
fi
```

**Rules:**

- Never `gh pr create` until both checks above are empty.
- Never open a second PR for the same head branch.
- Never open a second PR for the same Asana/topic/plan file if one open PR already carries that work (push to that branch instead).
- Prefer **one PR** containing plan doc + implementation when both exist.
- Body: what/why, plan link or path, test plan checklist from the plan.

## 4. Done criteria

- [ ] Plan steps implemented (or explicit gaps listed)
- [ ] Lint/tests green
- [ ] Pushed (after approval when required)
- [ ] **Exactly one** open PR for this work; URL reported
- [ ] Manual verification notes if the plan listed them
- [ ] Tracker comment posted if this work came from a tracker task (see Tracker comments)

## Integration with plan-implement-review

When invoked as the **implementer** inside `/plan-implement-review`:

1. Read plan path + branch from `/tmp/pir-<topic>/state.json` or the orchestrator prompt.
2. Run this skill fully (git start → implement → ensure PR).
3. **PIR pre-authorization:** the parent `/plan-implement-review` run typically authorizes feature-branch commit/push/PR for the implementer for that session — still never force-push, never remote DB, never second PR for same topic.
4. Write/update `state.json`: `feat_branch`, `implement_pr`, `session_id` if applicable.
5. Do not start a new plan PR; attach to existing plan branch/PR when present.

## Anti-patterns

- Ignoring tracker comments / opening a new PR when they already point at one
- Implementing without reading the plan / inventing extra scope
- Branching from a dirty feature branch instead of `origin/main` or the existing ticket PR branch
- Stashing/discarding WIP without asking
- Creating `fix/<topic>` when an open `plan/<topic>` PR already exists for the same work
- **`gh pr create` when a PR already exists** for this branch or same Asana topic
- Plan-only PR **and** separate implement PR left both open for the same work
- Silent commit/push/PR when project rules require approval and no session pre-auth
- Disabling tests/lint to get green
- Force-push / remote DB / migrations edits against project red lines without explicit approval
