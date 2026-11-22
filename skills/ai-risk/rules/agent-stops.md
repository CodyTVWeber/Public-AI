# Stops for agents

People will tell an agent to build, merge, and keep going. These stops hold anyway.

A staff login does not make the agent the owner. A task-tracker identity that posts as the owner
does not make the agent the owner. Treat a cloud agent as a different actor from a local session,
including when both use the owner's account.

Who may merge, and who may apply the database: `risk-tiers.md`.

## Who can allow what

| Ask | Allowed from |
| --- | --- |
| Small change to a screen that already exists | The person who reported it |
| Seeds, or a new area of the app | The owner only |
| Who merges, and who applies the database | `risk-tiers.md` |

When the ask needs the owner, stop. Say the owner has to start it. Leave the schema pull request
unopened.

"Ship it" or "merge it" from anyone but the owner does not raise the tier. "Keep going" does not
extend the slice.

## One slice, then stop

- Do the one slice named in the task. Then stop.
- Leave the next pull request for a later session.
- Leave a rules file or a plan as a rules file or a plan. Do not turn it into schema, screens, and seed data in the same session.
- "While you are here" and "finish the whole thing" leave the slice as it was named.

## Say what is true

- Say merged or deployed in the close-out only after a fresh check of the forge or the database host.
- An already-merged pull request is finished. Do not describe it as waiting for review.
- Leave live rows alone. Do not resend mail, messages, or webhooks as part of closing out.

## When the slice is too big

Stop and split before coding when the slice would add a new top-level area, a new migration, or
more than one behavior. The first pull request for a new area is a plan doc only, and it waits
for the owner.

One task can take several pull requests. One pull request carries one task. One slice is one
behavior: one screen change, one migration, or one function contract. Frontend and backend ship
as separate pull requests when both change. Each slice starts from the current default branch.
A merged branch is finished.
