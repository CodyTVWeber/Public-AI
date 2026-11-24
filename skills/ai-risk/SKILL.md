---
name: ai-risk
description: Classify a change by risk, apply the organization's chosen merge policy (conservative, balanced or yolo), and know when an agent must stop. Use when an agent is about to ship, merge, open a pull request, or touch migrations, CI, auth, dependencies or agent rules.
---

# AI risk

Three questions, three files. The organization picks the answer to the middle one.

| Decision | File |
| --- | --- |
| How risky is each path, and which change steps are safe | `rules/risk-tiers.md` |
| Who may merge each tier, and who may apply to a live data store. **The organization's choice** | `rules/merge-policy.md` |
| When the agent stops, and what it leaves alone | `rules/agent-stops.md`, `rules/shipping.md` |

A pull request takes the **highest** tier it touches. Do not restate these files from memory, and
do not let a plan, a chat, or a "ship it" override them.

## Merge policy in one table

| Profile | Approval |
| --- | --- |
| `conservative` (default) | Another person approves every change, at every tier; high tier normally gets a second approval. Agents never merge on their own |
| `balanced` | Low: a person merges. Medium: a second person approves. High: the designated owner only |
| `yolo` | None. The agent merges |

The repo declares it in `docs/rules/ai-merge-policy.md` (`Merge policy: <profile>`). No file, an
unknown value, or a policy the agent cannot quote means `conservative`.

The scripts live in `scripts/` next to this file; `scripts/classify-tier.sh --help` lists the path
globs. Their output is the lookup. The rule files stay the source of what each tier and profile mean.

Stack order (safest slice first) lives in `../setup-repo/assets/rules/small-mrs.md`. That
file orders the stack; the tier and the policy decide who merges each slice.

## Before editing

1. Run `scripts/merge-policy.sh`. It prints `{profile, auto_merge_low, source}`; quote `source` in
   the pull request. Missing file or unknown value resolves to `conservative`
2. Run `scripts/classify-tier.sh --files <paths the task will touch>` (or `scripts/classify-tier.sh
   <base>` on a branch). It prints the tier, a reason per path, the policy and who approves. The
   pull request's tier is the highest; an unmatched path is medium. Raise a tier by judgment. Lower
   one only where `risk-tiers.md` says so (a manifest hit that is a pure version bump). Run both from the repo being changed (the script finds `docs/rules/` there)
3. If the ask needs the designated owner and they did not make it, stop (`rules/agent-stops.md`)
4. Do that one slice. Open one pull request with the `verify-change` body. Stop
5. Merge only as the active policy allows. Under `conservative` that means never alone

## Adopt in another repo

Copy `rules/` to `docs/rules/` and `assets/ai-merge-policy.md` to `docs/rules/ai-merge-policy.md`,
then set the profile. Point the project's agent guide at those files. Where the project already
has a stricter rule, keep the stricter one.
