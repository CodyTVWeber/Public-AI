---
name: calendar-facts
description: >
  Keep calendar events self-contained. Use when creating or updating a
  calendar event, or checking that an event has address, logistics,
  confirmations, and source links.
---

# Calendar facts

This repo is **generic AI workflow**. Each event carries its own details, so it works without any other source.

## Where it goes

| Kind | Home |
|------|------|
| One event’s address, logistics, confirmations, links | **that calendar entry** (self-contained) |
| Standing facts reused across events | a notes repository you control |
| Generic recipes, skills, coding rules | this repo |

Do not copy concrete addresses, GPS, booking numbers, payment handles, or receipt URLs into this repo.

## Event entry (required fields)

Every event the user will act on must carry, when known:

- **Address** (as stated by the source — do not invent or geocode-guess)
- **Logistics** (arrival window, parking, what to bring, who goes)
- **Confirmations** (room, reservation, or booking numbers that exist)
- **Official link** (venue/host page)
- **Source-email link** plus a **searchable subject** (so mail can be found without the entry)

If a field is unknown, leave it blank and say so. Do not fill from memory. Check a drafted entry: `scripts/event-entry-lint.py FILE` (exit 1 lists missing labels).

This skill grants no new access or authority; follow the platform's existing connection, approval and safety rules.

## Do not

- Put concrete personal facts into this repo “for convenience”
- Treat a skill in this repo as the source of truth for a place or person
