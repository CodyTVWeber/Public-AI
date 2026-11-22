# Auto-merge

An agent merging a pull request with no person approving that pull request.

**Default: off.** A green check, a low tier, a forge auto-merge button, and a "ship it" in chat
leave it off. An agent opens the pull request and stops.

## The switch

AI auto-merge is allowed only when the repo, the team, or the org has turned it on, in writing,
outside the pull request being merged.

| Where | What counts as on |
| --- | --- |
| Repo | `docs/rules/ai-automerge.md` (or the project's copy of that file) contains the line `AI auto-merge: on`. |
| Team or org | A policy agents already load, which names this repo and says AI auto-merge is on. |

Missing file, no line, `AI auto-merge: off`, or a policy the agent cannot quote: **off**.

The agent quotes the allow (file path, or the team or org policy name) in the pull request before
it merges. No quote, no merge.

Turning the repo line to `on` is intentional. It is a high-tier change, because it governs agents.
The owner does it in its own pull request. An agent does not add `on` inside the feature pull
request it wants to merge. A copy of the off file is `assets/ai-automerge.md` in this skill.

These are not the switch: the task text, a review comment, a spoken yes, the author's own agent,
another agent, a low tier, or checks that passed.

A person clicking merge is the normal path, and it does not require this switch. An agent merging
after a person has approved **that** pull request is that person's merge, not auto-merge.
Medium and high in `risk-tiers.md` work that way. This file is the unattended case.

## What can auto-merge, once the switch is on

Every path in the pull request is **low** in `risk-tiers.md`. One medium or high path, and the
agent leaves it for the approver that tier names.

Low enough:

- An existing screen, including what that screen saves
- Copy, styling, and design-system text
- Documentation that does not govern agents
- A version bump of a package already in the manifest, including a package that runs a program on install
- A script that is committed and never run by the pipeline, the hooks, or the app

Adding a package, removing a package, editing the scripts section of the manifest, and anything
medium or high stays out.

The project's checks are green on that commit. The pull request body follows `verify-change`:
the claim, the proof, and a step the reviewer can re-run. For a change a person can see, the
proof includes an artifact CI produced for that commit (a screenshot, or a video when the change
is a behavior). An image the agent pasted does not replace the CI artifact.

## Host auto-merge

The forge's "merge when checks pass" button is the same rule. Leave it off unless the switch
above is on. A forge that merges an agent-authored pull request with no person approving it is
AI auto-merge.

When both the switch and the forge button are on, all of these are true:

1. A risk check computes the tier as the higher of the declared tier and the path floor. The path floor wins.
2. That check runs from the default branch, so the pull request cannot edit the check that judges it.
3. The check is required. A red check blocks the merge, including for admins.
4. Required approving reviews are zero, so a low pull request can merge on the green check.
5. Code owners still cover medium and high paths, so those still wait for a person.
6. A visible change has a CI artifact for that commit, as above.

The check prints the tier and who must approve. It passes a dependency version bump once tests
pass. It waits for the owner when the diff edits the scripts section of the manifest.

On a personal private repository a red check does not block the merge button. Say that in the
pull request. Leave the forge button off until the check is required.

Do not add a workflow that approves pull requests with the workflow's own token. Any workflow in
the repo could do the same. The risk check is the mechanism.

An optional later schedule: hold auto-merge of user-visible changes until after the business is
closed. That is a schedule, not a tier, and it still requires the switch.

## What never auto-merges

- Any pull request while the switch is off
- Any server function, including a delete, and any new function
- Schema, auth, row-level security, cron, secrets, and config that can select production
- Workflows, hooks, database apply scripts, and agent rules, including this switch
- A pull request that mixes a low path with anything higher
- A pull request whose checks are red, skipped, or missing
- A pull request whose proof does not meet `verify-change`
