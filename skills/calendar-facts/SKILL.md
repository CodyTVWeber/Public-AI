---
name: calendar-facts
description: >
  Keep calendar events self-contained. Use when creating or updating a
  calendar event, or checking that an event has address, logistics,
  confirmations, and source links.
---

# Calendar facts

Repo = **generic AI workflow**. Each event carries its own details; works without other sources.

## Where it goes

| Kind | Home |
|------|------|
| Event address, logistics, confirmations, links | **that calendar entry** |
| Standing facts reused across events | notes repo you control |
| Generic recipes, skills, coding rules | this repo |

Never copy into this repo: concrete addresses, GPS, booking numbers, payment handles, receipt URLs.

## Event entry (required fields)

Every actionable event carries, when known:

- **Address**: as stated by source. Never invent or guess-geocode.
- **Logistics**: arrival window, parking, what to bring, who goes
- **Confirmations**: room, reservation, booking numbers that exist
- **Official link**: venue/host page
- **Source-email link** + **searchable subject** (find mail without the entry)

- Unknown field: leave blank, say so. Never fill from memory.
- Lint draft: `scripts/event-entry-lint.py FILE` (exit 1 lists missing labels).

No new access or authority; follow platform connection, approval, safety rules.

## Never

- Put personal facts here "for convenience"
- Treat a repo skill as source of truth for a place or person
