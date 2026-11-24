# AI risk

Generic rules for shipping agent work: how risky a change is, who may merge it under the
organization's chosen policy, and when an agent must stop. The organization picks how much human
approval it wants: `conservative`, `balanced` or `yolo`.

## Use as a skill

Symlink or copy this directory to the agent's skills folder. The agent reads it before shipping,
merging, applying changes to a live data store, or continuing past the slice it was asked for.

## The rules

| File | Decides |
| --- | --- |
| `rules/risk-tiers.md` | Low, medium and high paths. Which change steps are safe and which are risky |
| `rules/merge-policy.md` | **The organization's choice.** Who may merge each tier under `conservative`, `balanced` and `yolo`, and how a repo declares its profile |
| `rules/agent-stops.md` | Who may ask an agent to continue. One slice, then stop |
| `rules/shipping.md` | Branch, pull request, local proof, controls that back the rules, and what an agent does not do to a live system |

| Profile | Approval |
| --- | --- |
| `conservative` (default) | Another person approves every change, at every tier; high tier normally gets a second approval |
| `balanced` | Low: a person merges. Medium: a second person approves. High: the designated owner only |
| `yolo` | None. The agent merges |

To adopt: copy `rules/` to `docs/rules/`, copy `assets/ai-merge-policy.md` to
`docs/rules/ai-merge-policy.md`, and set the `Merge policy:` line.

Two scripts do the lookups: `scripts/merge-policy.sh` (the declared profile, conservative when
unclear) and `scripts/classify-tier.sh` (tier per path, highest wins, who approves).

A pull request takes the highest tier it touches. Prompt rules guide a careful agent. They do not
block a merge until the forge can require a check; `rules/shipping.md` says what to put in place so
the rule and the button agree.

Stack order (safest change first) is the small-MR rule in `skills/setup-repo`. This skill
does not replace that. It says who is allowed to merge each tier. The pull request body that makes
the review easy is the `verify-change` skill.
