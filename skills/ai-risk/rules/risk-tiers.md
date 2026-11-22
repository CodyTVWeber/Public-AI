# Risk tiers

The only copy of who may merge, and who may apply the database. Other files point here.

A pull request takes the **highest** tier it touches. A screen plus a migration is high.

## Tiers

| Tier | Who may merge | What |
| --- | --- | --- |
| Low | After the project's checks pass, the agent that opened the pull request. | An existing screen, including what that screen saves. Copy, styling, and design-system text. Docs that are not rules for agents. A version bump of a package already in the manifest, including a package that runs a program on install. A script that is only committed and is not run by the pipeline, the hooks, or the app. |
| Medium | A second person approves on the pull request. That person is a maintainer and is not the author. A second agent does not count. A spoken yes does not count. Then that person's agent may merge. The author's agent must leave it. | Any file under the server-function tree, including a delete of a function nothing calls. A new function is medium. Reuse an existing function first. The pull request names the functions it looked at and why they do not fit. |
| High | Only the owner's agent, and only in a local session with the owner present. A cloud agent may open the pull request and must leave it unmerged, including when the forge login is the owner's. | Schema migrations. Workflow files. Git hooks. Scripts that apply, back up, restore, or schedule the hosted database. An edit to the scripts section of the package manifest. Adding a package or removing a package. A script the pipeline executes. Files that govern agents (rules, agent config, code owners). Auth, row-level security, cron, secret storage, and any config that can point a non-production host at production. |

- Schema migrations: do not add a test file here. The migrator applies every file in that folder.
- Workflows: the forge runs a workflow file in the workflows directory, not in a subdirectory. Leave the CI workflow where it is.
- Hooks: the pre-push hook stays on its current path.

## Same change, two speeds

The safe step can still be a high file. The tier says who merges it. The shape says which step lands first.
Clients keep the previous bundle until they update, so a drop that ships in the same release as the
UI that stops reading the old shape breaks anyone still on the old bundle.

| Change | Safe step | Risky step |
| --- | --- | --- |
| New column or new function parameter | Add it optional. Ship callers. | Make it required only after those callers and the data are in place. |
| A rule on a column | Loosening it. | Tightening it, and only after every existing row already fits. |
| Removing a column | Deprecate it. Stop writes. Move the data. | Delete it after those three. |

Destructive SQL (drop, rename, a new top-level data write) is high and carries a rollback note.
One migration pull request at a time. A new migration timestamp sorts after everything already on
the default branch.

## Database apply

Applying the database is separate from merging the file.

- The owner applies the database on their machine, right before merging a high pull request.
- The owner's agent may run that command while the owner is in the local session.
- A cloud agent writes the file and does not run it.
- Any other person's agent does not apply the database.
- These rules do not take a database password away from someone who already has it.

## Where this sits next to stack order

Order a stack safest-first: mechanical work, then inert or additive work, then the cutover.
That order is the small-MR rule. It does not lower a tier. An additive migration is still high
for who-merges, and it still lands before the migration that drops the old column.
