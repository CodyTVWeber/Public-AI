---
name: event-prep
description: >
  Work backward from event start to get-ready, load, and leave-by times. Use
  when preparing to attend an event, computing when to leave, or sequencing
  packing, gifts, or before-departure tasks.
---

# Event prep

Use calendar entry + user-supplied notes. Never invent places or times.

## Travel

1. Obtain + **verify origin and destination** from authorized sources (calendar entry, user notes, other connected sources the platform allows). See [`calendar-facts`](../calendar-facts/SKILL.md).
2. Either unresolved → **ask**. Never invent. Don't stop solely because entry lacks origin.
3. Authorized maps source available → get **real driving estimate** for both points. None → say so. Never fabricate time or assume a maps tool exists.
4. Report **traffic-aware** status and **when** estimate was produced. Claim **live traffic** only if source provides it. **Future** traffic = uncertain.
5. Never fabricate travel times, addresses, GPS.

No new access or authority; follow platform connection, approval, safety rules.

## Backward schedule

Work **back** from event start. Label each duration **stated** (from event/source) or **recommendation** (your suggestion).

| Step | Meaning |
|------|---------|
| Event start | From entry |
| Arrival buffer | Recommendation unless source requires a time |
| Depart | Start − buffer − drive estimate |
| Load | Recommendation; before depart |
| Get-ready | Recommendation; before load |
| Gift / other prep | Recommendation; before get-ready if it must travel |

**Output order chronological:** prep and before-departure tasks **above** depart line.

Compute: `scripts/event-backtime.mjs --start ISO --buffer-min N --drive-min N --load-min N --getready-min N [--prep-min N] [--stated drive,…] [--text]`. Prints ordered table with each step's basis (stated, estimate, recommendation). Pass only durations you have; minutes are inputs, not defaults.

Never invent deadlines. Prep duration = recommendation → say so.
