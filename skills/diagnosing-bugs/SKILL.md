---
name: diagnosing-bugs
description: A gated loop for a bug or slowdown that does not stay reproduced. Use when a failure is intermittent, a guess has already failed, or the user says diagnose or root cause.
argument-hint: "[symptom]"
---

# Diagnose

Do not patch until a command goes red on this bug.

| Phase | Exit when |
| --- | --- |
| Reproduce | A command, click, or query goes red on this bug and passes without it |
| Minimise | The smallest input or step list that still goes red |
| Hypothesise | One cause, and the observation that would rule it out |
| Instrument | That observation is recorded from a run |
| Fix | The minimise command passes |
| Lock | A regression test at the seam fails before the fix and passes after |

Say which phase you are in. A second hypothesis waits until the first observation is recorded.

Load [tdd](../tdd/SKILL.md) for the lock phase. Load [explain-code](../explain-code/SKILL.md) when a person must see the ordering.
