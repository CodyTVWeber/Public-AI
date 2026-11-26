---
name: review
description: Read-only multi-stage review of an implement branch or PR/MR against its plan. Runs only the review-* stage skills the diff needs (plan, logic, non-happy-logic, tests, security, data, ui, dependencies, infra, concurrency, code-quality, proof), then the regression gate. Use for "review this", /review, or the review phase of plan-implement-review-watch.
argument-hint: "[PR/MR number | branch] [plan path]"
---

# Review

Read-only. Never edit code; findings go back to the implementer. Host CLI: `gh` or `glab`, whichever the repo uses.

## 1. Pick stages

- `skills/review/scripts/stages.sh <base>` → `{stages:[{id, skill, active, reason, files[]}]}`. Thresholds: `stages.sh -h`
- `plan`, `proof`: always run
- Other stages: run only when `reason` shows a diff signal
- Name active stages in one line: `stages: plan, logic, security, proof`. Skipped stages need no mention
- Enable a skipped stage only when the diff plainly needs it; say why

| Skill | Looks at | Active when |
|---|---|---|
| [review-plan](../review-plan/review-plan.md) | scope vs plan, unplanned files, repo rules | always |
| [review-logic](../review-logic/review-logic.md) | main-path logic vs acceptance criteria | 5+ added non-test code lines |
| [review-non-happy-logic](../review-non-happy-logic/review-non-happy-logic.md) | errors, boundaries, nulls, timeouts, external-call failure | logic on, and added lines handle those |
| [review-tests](../review-tests/review-tests.md) | coverage and quality of tests | code or tests changed |
| [review-security](../review-security/review-security.md) | authn/authz, injection, secrets, crypto | security paths or risky tokens |
| [review-data](../review-data/review-data.md) | schema, migrations, queries | schema, model, migration, SQL |
| [review-ui](../review-ui/review-ui.md) | design fidelity, accessibility, states | UI files |
| [review-dependencies](../review-dependencies/review-dependencies.md) | added or bumped packages | manifest or lockfile |
| [review-infra](../review-infra/review-infra.md) | CI, containers, IaC, env, flags | config or deploy paths |
| [review-concurrency](../review-concurrency/review-concurrency.md) | races, retries, caches, unbounded work | locks, async, cache, retry, queries |
| [review-code-quality](../review-code-quality/review-code-quality.md) | clean-code floor, docs rule, via scripts | code or docs changed |
| [review-proof](../review-proof/review-proof.md) | the description proves the change | always |

- Findings: severity (bug · suggestion · nit), stage id, `file:line`, description, fix
- Prefer a project review skill for a stage when one exists
- Diff over ~400 lines with 3+ active stages → one read-only subagent per stage skill; merge results here. Smaller diffs: inline

## 2. Run

Run each active stage skill in table order; `proof` last. Any `bug` from any stage → verdict `fix required`.

## 3. Verdict

| Verdict | Next |
|---|---|
| approve | Regression gate (§4) |
| fix required, rounds left | Write `/tmp/pir-<topic>/review-roundN.md`; orchestrator resumes the same implementer agent |
| fix required, rounds spent | Stop; hand findings + implementer id to user; skip §4 |

## 4. Regression gate (after approve; required)

1. Command: repo's documented system-regression / end gate. None → `regression: skipped (no script)`; run lint + typecheck + unit tests on branch tip instead
2. Run on branch tip, clean tree. Fail → `regression: failed`; treat as `fix required` with log tail
3. Never call a run merge-ready without a pass or explicit user skip
4. Failures identical on base branch = pre-existing: report, don't block

## Output

Verdict · stages run · findings table (stage column) · evidence check result · regression status. ≤15 lines unless findings need more.
