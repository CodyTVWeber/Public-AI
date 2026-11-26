# Risk tiers

How risky a change is. Who may merge a change of each tier comes from the org's merge policy: `merge-policy.md`. Other files point here for the tier only.

A PR takes the **highest** tier it touches. Copy change + migration = high.

`scripts/classify-tier.sh` maps paths to tiers by glob (`--help` lists them), prints the highest, and names who approves under the active profile. It judges paths, not diffs. Raise a tier when the diff warrants it (e.g. script the pipeline starts running). Only lowering allowed: a manifest hit that only bumps a dependency already in the manifest is low. Adding or removing one stays high.

## Tiers

| Tier | What it means | Typical paths |
|---|---|---|
| Low | Easy to see, easy to undo, contained to one place | Existing screen, including what it saves. Copy, styling, design-system text. Tests only. Docs that don't govern agents. Version bump of dependency already in manifest. Script committed but not run by pipeline, hooks, or app |
| Medium | Changes behavior other code or users rely on; revert fixes it | Application logic and services. Adding, changing, or deleting an endpoint or server function (reuse an existing one first; name what you looked at). Public API surface added |
| High | Hard to undo, or controls how everything else is built, checked, run, or secured | Schema migrations. CI and workflow files. Git hooks. Scripts that apply, back up, restore, or schedule a data store. Scripts section of package manifest. Adding or removing a dependency. Files governing agents (rules, agent config, code owners, merge policy). Auth and access control. Scheduled jobs. Secret storage. Config that can point a non-production env at production |

Org may move a path between tiers in its copy of this file. Moving a path down needs designated owner's approval in its own PR.

## Same change, two speeds

Safe step can still touch a high path. Tier = who approves; shape = which step lands first. Clients keep the prior bundle until updated. A drop shipping in the same release as code that stops reading the shape it replaces breaks clients on the prior bundle.

| Change | Safe step | Risky step |
|---|---|---|
| Adding a column or function parameter | Add it optional. Ship callers | Make it required only after those callers and data are in place |
| Rule on a column | Loosen it | Tighten it, only after every existing row already fits |
| Removing a column | Deprecate it. Stop writes. Move the data | Delete it after those three |

Destructive data changes (drop, rename, top-level data write) are high and carry a written rollback note. One migration PR at a time; a migration is ordered after everything already on the default branch.

## Stack order

Order a stack safest-first: mechanical work, then inert or additive, then cutover. That order is the small-MR rule (`../../setup-repo/assets/rules/small-mrs.md`). It does not lower a tier: an additive migration is still high, and still lands before the migration that drops the column it replaces.
