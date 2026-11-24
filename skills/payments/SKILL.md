---
name: payments
description: >
  Distinguish estimated, agreed, and receipted amounts before closing a
  payment obligation. Use when researching a charge, recording or reconciling
  a payment, or marking a payment obligation done.
---

# Payments

Research is not authorization. Do not pay from this skill.

This skill grants no new access or authority; follow the platform's existing connection, approval and safety rules.

## Amount kinds

| Kind | What it is | Authorizes paying? | Closes the obligation? |
|------|------------|--------------------|------------------------|
| **Estimated** | Research or calculation | No | No |
| **Agreed** | User confirmed this amount | No (still needs a pay instruction) | No |
| **Receipted** | Actual completed receipt | Already paid | Only if recipient, amount, and purpose **all match** |

Keep the three distinct in every row. Do not collapse “I calculated $X” into agreed or paid.

## Closing

Close an obligation only when:

- An obligation **already exists** (do not invent a **Done** row to fill a table)
- **Recipient**, **amount**, and **purpose** match that obligation exactly
- A receipt (or the user confirming the payment completed) exists

Compare with `scripts/payment-match.py --expect JSON --actual JSON` (recipient, amount, purpose). Exit 1 → leave open and say which field differs; the script prints field names only, never values.

## Do not

- Treat research, a quote, or a calculator result as approval to pay
- Invent Done / paid rows
- Store payment handles, account numbers, or receipt URLs in this repo
