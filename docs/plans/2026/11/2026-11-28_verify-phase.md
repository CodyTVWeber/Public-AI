# Verify phase: prove the change with evidence

Date: 2026-11-28
**Branch:** `cursor/verify-phase-e993`
**Status:** draft

## Context

Scan of this public repo (`CodyTVWeber/Public-AI`; owner GitHub search, then this checkout). No other owner repo held a verification skill. What is already here:

| Piece | Job |
|---|---|
| [`verify-change`](../../../skills/verify-change/verify-change.md) | PR body is the proof (Build, Proof, Try it) |
| [`review-proof`](../../../skills/review-proof/review-proof.md) | Review stage that checks that body |
| implement §2.6 | Capture media to `/tmp`, attach to the PR, keep it out of git |
| [`check-work`](../../../skills/check-work/SKILL.md) | Self-verify subagent (`/check-work`) |
| `evidence-check.sh`, `proof-check.sh`, `check-pr-body.sh`, `upload-evidence.mjs` | Skeleton for capture and body shape |

Gaps: no PIR phase; path globs force proof kinds; no recipe next to the plan; no `/apir`; evidence never sits beside the plan.

User: the PR description is the proof a reviewer sees; do not bloat git; it is still useful for the recipe and a short index to live next to the plan. Evidence kinds depend on the solution.

Assumptions (background run; no blocking question): evolve `verify-change` rather than a third skill; `/verify` means this proof skill; `check-work` keeps `/check-work` and `/self-verify`.

No runtime change: monitoring skipped.

Read from: `origin/main` `8d9ccc9`.

## Why this approach

The PR description stays canonical so binaries never enter git (privacy blocks them anyway). A sibling folder named like the plan file holds the small recipe: scripts, `kinds.json`, `evidence.md`, tiny stdout. Reviewers still open the PR; later readers of the plan still see what was run and where the proof lives.

`pir-args` already owns the chain. Insert `verify` between `implement` and `review` when both are present (aliases and an auto-insert for old lists). Orchestrator runs `verify-change` there and again after a fix round.

Proof kinds are a menu. `diff-scope.sh` suggests; the agent writes `kinds.json`; `proof-check.sh` checks the pick, not every glob. Empty `kinds: []` is the pick for docs, comments, renames, and formatting: Build plus a **no behavior change** line. Do not invent screenshots or scripts.

## Concrete steps

1. `pir-args.sh`: phase `verify` (index after implement); auto-insert when implement and review are both listed; aliases `apir`, `verify` / `verify-only`; default and review-loop aliases include it
2. Rewrite `verify-change` playbook: pick kinds, plan folder, PR body, capture split (media on PR, small text optional next to the plan)
3. Scripts: `plan-dir.sh`, `check-evidence-dir.sh` (no binaries, 32KiB cap, kinds allowlist); tests
4. `proof-check.mjs`: when `scope.kinds` is set, check those kinds only
5. Orchestrator (`plan-implement-review-watch`): phase B2 Verify; implement defers when verify is in the run; `review-proof` reads `kinds.json` and the plan folder
6. Alias skills: `pir`, `pirw`, `ir`, `irw`, `apirw`, `apirwm`, `implement-review`, `implement-review-watch`; add `apir` and `verify`
7. `skills-manifest.json`, bootstrap-skills test, setup-repo README, `AGENTS.md` table, `check-work` description
8. Dogfood: sibling folder for this plan, `kinds: [script]`, commit script stdout (tiny); paste the same on the PR

## Risks

- Auto-insert changes `phases=plan,implement,review` output. Tests and alias docs must show `verify` in the middle. Old prompts that listed phases by hand still work because of the insert.
- `check-work` losing `/verify` is the collision fix. Self-verify stays on `/check-work`.

## Out of scope

- Moving `evidence-check.sh` / `upload-evidence.mjs` out of `skills/implement/scripts/`
- GitLab upload rewrite
- Forcing `pi` / `implement-only` through the verify phase (implement §2.6 remains the fallback)

## Verification

| Claim | How |
|---|---|
| Aliases insert verify | `pir-args.sh` tests |
| Plan folder gate | `check-evidence-dir.sh` tests |
| Picked kinds, not globs | `proof-check.sh` with `{"kinds":["script"]}` |
| This change proves itself | sibling `verify.sh` stdout on the PR and in `out/` |
