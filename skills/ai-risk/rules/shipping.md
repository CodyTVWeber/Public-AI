# Shipping

How an agent ships. Tier: `risk-tiers.md`. Who merges: `merge-policy.md`. When to stop:
`agent-stops.md`. The proof a reviewer re-runs: the `verify-change` skill.

## What you do

1. Branch from the default branch; open the pull request into the default branch
2. Validate schema and data changes on a local database before pushing
3. Search open pull requests first. When this task already has one, commit there
4. Push the feature branch, open the pull request with the `verify-change` body, and stop unless
   the active policy lets you merge

A change to migrations or server code is proved on a non-production preview before it merges.
The agent does not create previews or connect projects that are not already connected. The
pipeline proves a migration was recorded and code was deployed, not that it behaves: run the new
behavior on the preview and write down what you saw.

A merge to the default branch can apply to every environment connected to it. Merge only when
every one of those environments should receive the change.

## What you leave alone

- The default branch: no direct pushes, no skipped hooks
- Creating hosted preview environments by hand, or connecting a project that is not connected
- Pointing a preview at production with a query parameter or saved browser state
- Hosted SQL, deploys and data-apply scripts against a shared or live data store
- Debug, discovery or speculative changes in production
- A second writer that applies data changes from CI while the vendor integration also applies on
  merge. One writer

Schema and code checks run locally. Hosted non-production and live are not sandboxes: production
receives a change that already proved itself in a lower environment. The exception is an explicit,
one-time directive for one named investigative action in production; ask first and name the risk.

## Rules are not a lock

Prompt rules stop an agent that loads and follows them. They do not stop another tool, a hook
bypass, the website, or an agent whose user said to ship. A credential can change live data with
no push. Back the rules with controls, sized to the profile in `merge-policy.md`:

- Take write-capable data credentials out of agent environments; leave read-only access to a
  non-production store
- Agents authenticate as a bot user that is not an admin. Under `conservative` and `balanced`
  the bot is not on the default branch's push allow-list
- Protect the default branch: require a pull request, dismiss stale approvals, block force-push
  and deletion, apply the rules to admins. Code owners cover the data tree and the files that
  govern agents
- Where a repo cannot require any of that, keep write access with the owner alone

A check that lives in the pull request can be deleted by that pull request. Run the risk check
from the default branch.

## Loud check

A required check on the default branch computes the tier (the higher of the declared tier and the
path floor) and prints who must approve under the active profile. It stays red until they have.
Until the forge can require a check, this is a design, not a gate.
