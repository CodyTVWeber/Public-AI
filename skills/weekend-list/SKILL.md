---
name: weekend-list
description: >
  Build a printable one-sheet weekend checklist. Use when asked for a weekend
  list, a printable weekend checklist, or a Friday–Sunday paper plan.
---

# Weekend list

One **beautiful, readable** checklist. Deliver the rendered sheet, not status chatter.

## Layout

- **US Letter**, one sheet, **duplex long-edge** when it fits
- Checkboxes large enough to mark
- Legible body type (readable at arm’s length). Do not shrink to cram
- **No URLs.** For mail-sourced items, print the **searchable subject**
- Dates on every dated item. Mark **conditional** items as conditional
- Do **not** invent priorities, owners, or due dates

## Sections (in this order)

| Section | What belongs |
|---------|----------------|
| **Carryover** | Still-open items from before this weekend |
| **Weekend** | This Saturday–Sunday (dates: `scripts/weekend-dates.py`, JSON) |
| **Weekday prep** | Work for the coming week, not this weekend’s doing |

Put an item in **one** section. Source and date decide the bucket — not a made-up P0/P1.

## Verify, then stop

1. Render (print preview or PDF).
2. `scripts/sheet-check.sh FILE.pdf`: Letter size, **≤2 pages** (one sheet duplex), no URLs. Exit 1 → fix; if it overflows, report what does not fit; do not make type unreadably small. Skipped checks (no poppler) → eyeball them.
3. **Print only when the user asked to print.** Generating the file is not printing.

Related: [`event-prep`](../event-prep/SKILL.md) for leave-by times — do not invent them here.
