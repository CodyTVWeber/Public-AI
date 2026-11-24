# Risk tiers

How risky a change is. Who may merge a change of each tier comes from the organization's merge
policy: `merge-policy.md`. Other files point here for the tier only.

A pull request takes the **highest** tier it touches. A copy change plus a migration is high.

`scripts/classify-tier.sh` maps paths to these tiers by glob (`--help` lists them), prints the
highest, and names who approves under the active profile. It judges paths, not diffs. Raise a tier
when the diff warrants it (a script the pipeline starts running). The one lowering it allows: a
manifest hit that only bumps a dependency already in the manifest is low; adding or removing one
stays high.

## Tiers

| Tier | What it means | Typical paths |
| --- | --- | --- |
| Low | Easy to see, easy to undo, contained to one place | An existing screen, including what it saves. Copy, styling, design-system text. Tests only. Docs that do not govern agents. A version bump of a dependency already in the manifest. A script that is committed but not run by the pipeline, hooks or app |
| Medium | Changes behavior that other code or users rely on, and a revert fixes it | Application logic and services. A new, changed or deleted endpoint or server function (reuse an existing one first, and name what you looked at). A new public API surface |
| High | Hard to undo, or it controls how everything else is built, checked, run or secured | Schema migrations. CI and workflow files. Git hooks. Scripts that apply, back up, restore or schedule a data store. The scripts section of the package manifest. Adding or removing a dependency. Files that govern agents (rules, agent config, code owners, the merge policy). Auth and access control. Scheduled jobs. Secret storage. Config that can point a non-production environment at production |

An organization may move a path between tiers in its copy of this file. Moving a path down needs
the designated owner's approval in its own pull request.

## Same change, two speeds

The safe step can still touch a high path. The tier says who approves; the shape says which step
lands first. Clients keep the previous bundle until they update, so a drop that ships in the same
release as the code that stops reading the old shape breaks anyone still on the old bundle.

| Change | Safe step | Risky step |
| --- | --- | --- |
| New column or new function parameter | Add it optional. Ship callers | Make it required only after those callers and the data are in place |
| A rule on a column | Loosening it | Tightening it, and only after every existing row already fits |
| Removing a column | Deprecate it. Stop writes. Move the data | Delete it after those three |

Destructive data changes (drop, rename, a new top-level data write) are high and carry a written
rollback note. One migration pull request at a time; a new migration is ordered after everything
already on the default branch.

## Where this sits next to stack order

Order a stack safest-first: mechanical work, then inert or additive work, then the cutover.
That order is the small-MR rule (`../../setup-repo/assets/rules/small-mrs.md`). It does not
lower a tier: an additive migration is still high, and it still lands before the migration that
drops the old column.
