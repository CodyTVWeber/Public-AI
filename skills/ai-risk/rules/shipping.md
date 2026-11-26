# Shipping

How an agent ships. Tier: `risk-tiers.md`. Who merges: `merge-policy.md`. When to stop: `agent-stops.md`. Proof a reviewer re-runs: `verify-change` skill.

## What you do

1. Branch from default branch; open PR into default branch
2. Validate schema and data changes on a local database before pushing
3. Search open PRs first. Task already has one → commit there
4. Push feature branch; open PR with `verify-change` body; stop unless active policy lets you merge

Migration or server code change: prove on a non-production preview before merge. Agent doesn't create previews or connect projects not already connected. Pipeline proves migration recorded and code deployed, not that it behaves: run the changed behavior on preview, write down what you saw.

Merge to default branch can apply to every environment connected to it. Merge only when every one of those should receive the change.

## What you leave alone

- Default branch: no direct pushes, no skipped hooks
- Creating hosted preview environments by hand, or connecting an unconnected project
- Pointing a preview at production via query parameter or saved browser state
- Hosted SQL, deploys, data-apply scripts against shared or live data store
- Debug, discovery, or speculative changes in production
- Second writer applying data changes from CI while vendor integration also applies on merge. One writer

Schema and code checks run locally. Hosted non-production and live are not sandboxes: production receives a change that already proved itself in a lower env. Exception: explicit, one-time directive for one named investigative action in production. Ask first; name the risk.

## Rules are not a lock

Prompt rules stop an agent that loads and follows them. They don't stop another tool, a hook bypass, the website, or an agent whose user said ship. A credential can change live data with no push. Back rules with controls, sized to profile in `merge-policy.md`:

- Take write-capable data credentials out of agent envs; leave read-only access to non-production store
- Agents authenticate as bot user, not admin. Under `conservative` and `balanced`, bot is not on default branch push allow-list
- Protect default branch: require PR, dismiss stale approvals, block force-push and deletion, apply rules to admins. Code owners cover data tree and agent-governing files
- Repo can't require these → keep write access with owner alone

A check living in the PR can be deleted by that PR. Run risk check from default branch.

## Loud check

Required check on default branch computes tier (higher of declared tier and path floor) and prints who must approve under active profile. Stays red until they have. Until forge can require a check, this is a design, not a gate.
