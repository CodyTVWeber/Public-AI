# Auto-merge

What an agent may merge with no second person, and what has to be true before the forge's
auto-merge switch is safe to turn on.

Eligible work is a pull request whose every path is **low** in `risk-tiers.md`. One medium or
high path takes the pull request out of this file. The authoring agent leaves it for the approver
that tier names.

## What is low enough

- An existing screen, including what that screen saves
- Copy, styling, and design-system text
- Documentation that does not govern agents
- A version bump of a package already in the manifest, including a package that runs a program on install
- A script that is committed and never run by the pipeline, the hooks, or the app

Adding a package, removing a package, editing the scripts section of the manifest, and anything
in `risk-tiers.md` under medium or high stays out.

## The agent may merge a low pull request

The agent that opened it may merge after the project's checks are green on that commit.
Tests, lint, and build are that bar. The agent says the tier in the pull request body.

For a change a person can see, prefer a stronger bar before anyone leans on this: an artifact the
CI system produced for that commit, a screenshot or a video. An image the agent uploaded does not
qualify. The living minimum, when the forge cannot require that artifact yet, is green checks.

## Host auto-merge

Turn the forge's auto-merge switch on only after all of these are true:

1. A risk check computes the tier as the higher of the declared tier and the path floor. The path floor wins.
2. That check runs from the default branch, so the pull request cannot edit the check that judges it.
3. The check is required. A red check blocks the merge, including for admins.
4. Required approving reviews are zero, so a low pull request can merge on the green check.
5. Code owners still cover medium and high paths, so those still wait for a person.
6. A visible change has a CI artifact for that commit, produced by CI, as above.

The check prints the tier and who must approve. It passes a dependency version bump once tests
pass. It waits for the owner when the diff edits the scripts section of the manifest.

Leave the switch off until the check is required. On a personal private repository a red check
does not block the merge button. Say that in the pull request. Do not describe a red check as a
lock it is not.

Do not add a workflow that approves pull requests with the workflow's own token. Any workflow in
the repo could do the same. The risk check is the mechanism.

An optional later switch: hold auto-merge of user-visible changes until after the business is
closed. That is a schedule, not a tier.

## What never auto-merges

- Any server function, including a delete, and any new function
- Schema, auth, row-level security, cron, secrets, and config that can select production
- Workflows, hooks, database apply scripts, and agent rules
- A pull request that mixes a low path with anything higher
- A pull request whose checks are red, skipped, or missing
