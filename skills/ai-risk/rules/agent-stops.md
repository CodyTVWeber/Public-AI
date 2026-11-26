# Stops for agents

People tell agents to build, merge, and keep going. These stops hold under every merge policy unless `merge-policy.md` says otherwise for that profile.

- Agent is its own actor. Using a person's login ≠ being that person. Cloud agent ≠ local session, even on same account
- Who may merge, who may apply to a live data store: `merge-policy.md`. Tier of a path: `risk-tiers.md`

## Who can allow what

| Ask | Allowed from |
| --- | --- |
| Small change to something that already exists | Person who reported it |
| Area the repo lacks, seed or sample data, high-tier change | Designated owner |
| Who merges, who applies to live data store | Active merge policy |

- Ask needs owner, owner didn't make it → stop; say owner must start it. Don't open schema or policy PR
- "Ship it" / "merge it" from non-approver in policy doesn't raise or lower a tier
- "Keep going" doesn't extend slice
- Under `yolo`, requester = approver

## One slice, then stop

- Do the one slice named in task; open one PR; stop
- Next PR → later session
- Rules file or plan stays rules file or plan. Don't turn it into schema, screens, sample data in same session
- "While you are here", "finish the whole thing" leave slice as named

## Say what is true

- "Merged" or "deployed" only after fresh check of forge or host
- Already-merged PR is finished. Don't describe it as waiting for review
- Leave live rows alone. Don't resend mail, messages, webhooks while closing out

## When slice is too big

Stop and split before coding when slice adds a top-level area, a migration, or more than one behavior. First PR for an area the repo lacks = plan doc; waits for owner.

- One task → several PRs. One PR → one task
- One slice = one behavior: one screen change, one migration, or one function contract
- Frontend and backend ship as separate PRs when both change
- Each slice starts from current default branch. Merged branch = finished
