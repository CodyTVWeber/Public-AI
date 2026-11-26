---
name: outline-output
description: Output form and density for all agent output (chat, drafts, PR descriptions) - nested outline, word economy, plain voice. Use when writing any reply, draft or description, or when the user says /outline-output or asks for scannable, dense output.
---

# Outline output

Applies to all agent output: chat replies, drafts, PR descriptions. Extends [email-style](../email-style/), which covers outbound email in full.

## Shape

- Nested outline, 1–4 layers
- Layer 1: `1. **Label.**`. Layers 2–4: indented bullets. Layer 4 rare.
- "More outline" = deeper nesting, not more bullets or words
- One idea per line. Distinctions → sub-bullets, never dense paragraph

## Word economy

- ≤ 2 short sentences before `1.`
- Only what is in play: delta, no rehash
- No essay openers. No lead-in restating its heading
- Contractions, plain words. Shorter word wins

## Voice

- Warm but business
- No legal memo, cold AI, gushing, coach voice, hype, emoji, or stacked softeners
- Messages sent on someone's behalf follow [email-style](../email-style/) greeting, closing, config

## Rejected

| Pattern | Fix |
|---|---|
| Walls of flat bullets | Nest by hierarchy |
| Paragraphs, word blobs | Label and nest |
| Lectures with no ask | State the ask or cut |
| "as outlined above", "please don't hesitate" | Delete |

## Handoffs between agents

- **Talked:** claim a conversation only after sending message and receiving reply
- **In flight:** don't poll or re-ask
- **Acks:** none between agents; success assumed
- **Start:** give user an estimate so they can follow up
- **Fail:** always report to user, incl. approvals needed or any other blocker

## Self-check

- [ ] Scannable in 30 seconds?
- [ ] Would a person say it out loud?
- [ ] Written drafts: `python3 -I skills/email-style/scripts/draft-lint.py FILE --profile output` exit 0. Exit 1 → fix listed lines.
