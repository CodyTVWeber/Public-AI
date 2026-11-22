# Stops for agents

People will tell an agent to build, merge, and keep going. These stops hold under every merge
policy unless `merge-policy.md` says otherwise for that profile.

An agent is its own actor. Using a person's login does not make it that person. A cloud agent is a
different actor from a local session, including when both use the same account.

Who may merge, and who may apply to a live data store: `merge-policy.md`. Tier of a path:
`risk-tiers.md`.

## Who can allow what

| Ask | Allowed from |
| --- | --- |
| Small change to something that already exists | The person who reported it |
| A new area, seed or sample data, a high-tier change | The designated owner |
| Who merges, and who applies to a live data store | The active merge policy |

When the ask needs the owner and the owner did not make it, stop and say the owner has to start
it. Do not open the schema or policy pull request.

"Ship it" or "merge it" from someone who is not the approver in the policy does not raise or lower
a tier. "Keep going" does not extend the slice. Under `yolo` the requester is the approver.

## One slice, then stop

- Do the one slice named in the task, open one pull request, then stop
- Leave the next pull request for a later session
- A rules file or a plan stays a rules file or a plan. Do not turn it into schema, screens and
  sample data in the same session
- "While you are here" and "finish the whole thing" leave the slice as named

## Say what is true

- Say merged or deployed only after a fresh check of the forge or the host
- An already-merged pull request is finished. Do not describe it as waiting for review
- Leave live rows alone. Do not resend mail, messages or webhooks while closing out

## When the slice is too big

Stop and split before coding when the slice would add a new top-level area, a new migration, or
more than one behavior. The first pull request for a new area is a plan doc, and it waits for the
owner.

One task can take several pull requests. One pull request carries one task. One slice is one
behavior: one screen change, one migration, or one function contract. Frontend and backend ship as
separate pull requests when both change. Each slice starts from the current default branch. A
merged branch is finished.
