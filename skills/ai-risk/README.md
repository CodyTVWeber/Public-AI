# AI risk

Generic rules for shipping agent work: how risky a change is, who may merge it, when an agent
must stop, and which changes may auto-merge.

## Use as a skill

Symlink or copy this directory to the agent's skills folder. The agent reads it before shipping,
merging, applying a database, or continuing past the slice it was asked for.

## The rules

| File | Decides |
| --- | --- |
| `rules/risk-tiers.md` | Low, medium, and high paths. Who may merge. Who may apply the database. |
| `rules/agent-stops.md` | Who may ask an agent to continue. One slice, then stop. |
| `rules/automerge.md` | The only band an agent may merge alone, and when a forge auto-merge switch is safe to turn on. |
| `rules/shipping.md` | Branch, pull request, local proof, and the things an agent does not do to a live system. |

A pull request takes the highest tier it touches. Prompt rules guide a careful agent. They do not
block a merge until the forge can require a check. `rules/shipping.md` says what to put in place
so the rule and the button agree.

Stack order (safest change first) is the small-MR rule in `skills/setup-clean-code`. This skill
does not replace that. It says who is allowed to merge each tier.
