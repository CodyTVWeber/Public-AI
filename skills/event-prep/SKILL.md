---
name: event-prep
description: >
  Work backward from event start to get-ready, load, and leave-by times. Use
  when preparing to attend an event, computing when to leave, or sequencing
  packing, gifts, or before-departure tasks.
---

# Event prep

Use the calendar entry and any notes the user supplies. Do not invent places or times.

## Travel

1. Obtain and **verify origin and destination** from available authorized sources (calendar entry, notes the user supplies, other connected sources the platform already allows). See [`calendar-facts`](../calendar-facts/SKILL.md).
2. If either remains unresolved, **ask**. Do not invent. Do not stop solely because the event entry lacks origin.
3. If an authorized maps source is available, get a **real driving estimate** for those two points. If none is available, say so — do not fabricate a time or assume a maps tool exists.
4. Report whether the estimate is **traffic-aware** and **when** it was produced. Claim **live traffic** only if that source provides it. Treat **future** traffic as uncertain.
5. Do not fabricate travel times, addresses, or GPS.

This skill grants no new access or authority; follow the platform's existing connection, approval and safety rules.

## Backward schedule

Work **back** from event start. Label every duration as **stated** (from the event/source) or **recommendation** (your suggestion).

| Step | Meaning |
|------|---------|
| Event start | From the entry |
| Arrival buffer | Recommendation unless the source requires a time |
| Depart | Start − buffer − drive estimate |
| Load | Recommendation; before depart |
| Get-ready | Recommendation; before load |
| Gift / other prep | Recommendation; before get-ready if it must travel |

**Output order is chronological:** prep and before-departure tasks **above** the depart line. Compute it: `scripts/event-backtime.py --start ISO --buffer-min N --drive-min N --load-min N --getready-min N [--prep-min N] [--stated drive,…] [--text]` prints the ordered table with each step's basis (stated, estimate, recommendation). Pass only durations you have; the minutes are inputs, not defaults.

Do not invent deadlines. If a prep duration is a recommendation, say so.
