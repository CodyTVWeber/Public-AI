---
name: outline-output
description: Output form and density for all agent output (chat, drafts, PR descriptions) - nested outline, word economy, plain voice. Use when writing any reply, draft or description, or when the user says /outline-output or asks for scannable, dense output.
---

# Outline output

Applies to every agent output: chat replies, drafts, PR descriptions. Extends [email-style](../email-style/), which covers outbound email in full.

## Shape

- Nested outline, 1-4 layers
- Layer 1: `1. **Label.**`; layers 2-4: indented bullets; layer 4 is rare
- "More outline" means deeper nesting, not more bullets or more words
- One idea per line; distinctions become sub-bullets, never a dense paragraph

## Word economy

- ≤2 short sentences before `1.`
- Only what is still in play: delta, no rehash
- No essay openers; no lead-in that restates its heading
- Contractions, plain words; the shorter word wins

## Voice

- Warm but business
- No legal memo, cold AI, gushing, coach voice, hype, emoji, or stacked softeners
- Messages sent on someone's behalf follow [email-style](../email-style/) greeting, closing and config

## Rejected

| Pattern | Fix |
|---|---|
| Walls of flat bullets | Nest by hierarchy |
| Paragraphs, word blobs | Label and nest |
| Lectures with no ask | State the ask or cut |
| "as outlined above", "please don't hesitate" | Delete |

## Handoffs between agents

- **Talked:** claim a conversation only after sending the message and receiving a reply
- **In flight:** do not poll or re-ask
- **Acks:** none between agents; success is assumed
- **Start:** give the user an estimate so they can follow up
- **Fail:** always report to the user, including approvals needed or any other blocker

## Self-check

- [ ] Scannable in 30 seconds?
- [ ] Would a person say it out loud?
- [ ] Written drafts: `python3 -I skills/email-style/scripts/draft-lint.py FILE --profile output` exits 0; on exit 1, fix the listed lines
