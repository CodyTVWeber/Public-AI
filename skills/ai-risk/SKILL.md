---
name: ai-risk
description: Classify change risk, apply the org's merge policy (conservative, balanced or yolo), know when an agent must stop. Use when an agent is about to ship, merge, open a pull request, or touch migrations, CI, auth, dependencies or agent rules.
---

# AI risk

Three questions, three files. The org picks the answer to the middle one.

| Decision | File |
| --- | --- |
| How risky is each path; which change steps are safe | `rules/risk-tiers.md` |
| Who may merge each tier; who may apply to a live data store. **The org's choice** | `rules/merge-policy.md` |
| When agent stops; what it leaves alone | `rules/agent-stops.md`, `rules/shipping.md` |

PR takes the **highest** tier it touches. Don't restate these files from memory. Don't let a plan, chat, or "ship it" override them.

## Merge policy in one table

| Profile | Approval |
| --- | --- |
| `conservative` (default) | Another person approves every change, every tier; high tier normally gets a second approval. Agents never merge on their own |
| `balanced` | Low: a person merges. Medium: second person approves. High: designated owner only |
| `yolo` | None. Agent merges |

Repo declares it in `docs/rules/ai-merge-policy.md` (`Merge policy: <profile>`). No file, unknown value, or policy agent can't quote → `conservative`.

Scripts live in `scripts/` next to this file; `scripts/classify-tier.sh --help` lists path globs. Their output is the lookup. Rule files stay the source of what each tier and profile mean.

Stack order (safest slice first): `../setup-repo/assets/rules/small-mrs.md`. That file orders the stack; tier and policy decide who merges each slice.

## Before editing

1. Run `scripts/merge-policy.sh`. Prints `{profile, auto_merge_low, source}`; quote `source` in PR. Missing file or unknown value → `conservative`
2. Run `scripts/classify-tier.sh --files <paths task will touch>` (or `scripts/classify-tier.sh <base>` on a branch). Prints tier, reason per path, policy, approver. PR tier = highest; unmatched path = medium. Raise tier by judgment. Lower only where `risk-tiers.md` says so (manifest hit that is pure version bump). Run both from the repo being changed (script finds `docs/rules/` there)
3. Ask needs designated owner and they didn't make it → stop (`rules/agent-stops.md`)
4. Do that one slice. Open one PR with `verify-change` body. Stop
5. Merge only as active policy allows. Under `conservative`: never alone

## Adopt in another repo

Copy `rules/` to `docs/rules/` and `assets/ai-merge-policy.md` to `docs/rules/ai-merge-policy.md`, then set profile. Point project's agent guide at those files. Where project already has stricter rule, keep stricter one.
