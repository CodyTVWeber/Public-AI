---
name: payments
description: >
  Distinguish estimated, agreed, and receipted amounts before closing a
  payment obligation. Use when researching a charge, recording or reconciling
  a payment, or marking a payment obligation done.
---

# Payments

- Research is not authorization. Never pay from this skill.
- Grants no access or authority. Follow platform's existing connection, approval, safety rules.

## Amount kinds

| Kind | What it is | Authorizes paying? | Closes obligation? |
|------|------------|--------------------|--------------------|
| **Estimated** | Research or calculation | No | No |
| **Agreed** | User confirmed amount | No (needs pay instruction) | No |
| **Receipted** | Actual completed receipt | Already paid | Only if recipient, amount, purpose **all match** |

Keep three distinct in every row. Never collapse "I calculated $X" into agreed or paid.

## Closing

Close obligation only when:

- Obligation **already exists**. Never invent a **Done** row to fill a table.
- **Recipient**, **amount**, **purpose** match that obligation exactly.
- Receipt exists (or user confirms payment completed).

Compare: `scripts/payment-match.py --expect JSON --actual JSON` (recipient, amount, purpose). Exit 1 → leave open, say which field differs. Script prints field names only, never values.

## Do not

- Treat research, quote, or calculator result as approval to pay
- Invent Done / paid rows
- Store payment handles, account numbers, or receipt URLs in this repo
