# Shipping

How an agent ships. Who may merge, and who may apply the database: `risk-tiers.md`.
When the agent stops: `agent-stops.md`. AI auto-merge defaults to off: `automerge.md`.
The proof a reviewer re-runs: the `verify-change` skill.

## What you do

1. Branch from the default branch and open the pull request into the default branch.
2. Validate schema on a local database before pushing.
3. Push the feature branch and open the pull request.
4. Search open pull requests first. When this task already has an open documentation pull request, commit there.

A pull request that changes migrations or server functions is proved on a non-production preview
before it merges. The agent does not create that preview and does not connect a project that is
not already connected. The check reads the preview. A skipped check from production does not count.

The pipeline can prove a migration was recorded and a function was deployed. It does not exercise
the function. Before merge, run the new behavior on the preview and write down what you saw. The
page's database host is the preview.

A merge to the default branch applies to every environment that integration is connected to.
Merge a change only when every one of those environments should receive it.

## What you leave alone

- The default branch. That includes pushing the current branch straight to it, and skipping hooks.
- Creating hosted preview branches by hand, or connecting a project that is not already connected.
- Pointing a preview host at production with a query parameter or with saved browser state.
- Hosted SQL, function deploys, and database-apply scripts against a shared or live database.
- Debug, discovery, or speculative changes on production: functions, database, and infrastructure.
- A second writer that applies the database from CI while the vendor's integration also applies on merge. One writer.

Schema and function checks run on the local database. Hosted non-production and live are not
sandboxes. Production receives a change that already proved itself in a lower environment.
The exception is an explicit, one-time directive to do one named investigative action in
production. When the data or the credential exists only in production, ask first and name the risk.

## Rules are not a lock

Prompt rules stop an agent that loads them and follows them. They do not stop a different tool,
a hook bypass, the website, or an agent whose user said to ship. A database credential can change
live data with no git push.

Put these in place so the rule and the button agree:

- Take write-capable database credentials out of agent environments. Leave read-only access to a non-production project. A higher forge plan does not close that hole.
- Agents authenticate as a bot user with write. The owner stays the reviewer for high. The bot user is not an admin.
- Protect the default branch on a plan that can require a pull request, dismiss stale reviews, block force-push and deletion, apply the rules to admins, and keep the bot off the push allow-list. Code owners cover the database tree and the files that govern agents.
- A personal private repository often cannot require any of that. The free control that blocks other people is to leave write with the owner alone. That also stops them pushing feature branches, and the owner's own agents can still push, because nothing includes the admin.

A check that runs from the default branch can fail when a protected path changes. A check that
lives in the pull request can be deleted by that pull request. Do not hash a folder and fail when
the hash changes: that freezes every real edit, and a workflow change in the same repo can skip it.

When the database vendor deploys on merge, an environment-approval button on the forge never sees
that job. The gate is the pull request. Do not move the repository, or replace the site host, to
get the lock. A static host can serve the built site and still gives no per-pull-request database.

## Loud check

Add this once the forge can require a check. Until then it is a design, not a gate.

One workflow on the default branch, so the pull request cannot edit the check that judges it.

| Diff touches | Check fails until |
| --- | --- |
| A medium path | A second person, not the author, has approved on the pull request |
| A high path | The owner has approved |
| Dependency version bumps only | The project's checks are green |
| The scripts section of the manifest | The owner has approved |
| Anything else low | The project's checks are green |

Put the check's tests beside the workflow or under the database-script tree, in a place a low
pull request cannot edit.
