---
name: email-style
description: Draft outbound email in a plain, scannable, human business voice - nested outline, delta-only, light source tags, document-shaped asks. Use when drafting or rewriting an email, when the user says /email-style, "sound like me", or "not AI-sounding".
argument-hint: "[topic or thread]"
---

# Email style

Ready-to-send markdown, human business voice. Default: nested outline, 1-4 layers.

## When

- Any outbound email: vendor, client, partner, external
- Triggers: "my voice", "not AI-sounding", "scannable"
- Not for internal logs, plans, debriefs → [outline-output](../outline-output/)

## Shape

| Layer | Form |
|---|---|
| 1 | `1. **Label.**` numbered topics |
| 2-4 | Indented bullets; layer 4 rare |

- "More outline" = deeper nesting where hierarchy helps. Not more bullets or words.
- One idea per line. Distinctions → sub-bullets, never dense paragraph.
- Open topics only: skip settled items nobody debates (delta only).

## Skeleton

```markdown
**To:** Recipient
**Cc:** Observer
**Subject:** Topic

Hi Recipient,

One short purpose sentence.

1. **Topic under decision**
   - Parent point
     - Child detail
       - Grandchild only when it clarifies a fork
   - Sibling point

2. **Next topic**
   - Point

Also for the record (already agreed, needs to be written down):
- **Item:** short confirmation

Close line. Offer a call if useful.

Closing,
Sender Name
```

- `Cc` omitted when empty.
- Greeting, closing, signature, phone from user config ([Config](#config)). Nothing personal in this repo.

## Voice

| Do | Avoid |
|---|---|
| Warm but business; talk like a person | Legal memo, cold AI, gushing |
| Greeting + name, straight to purpose | Small talk by default, "hope you're well" |
| Contractions, plain words | "pursuant", "aforementioned", "leverage", "ensure alignment" |
| Tag sources lightly: "your Tuesday email", "on the call", "the renewal quote", "your text" | Re-teaching facts reader knows |
| Assume recipient shares sender's time zone; omit labels | Time-zone labels on times |
| Plain close, offer a call | "Please don't hesitate", "as outlined above", stacked softeners |

## Content Rules

1. **Opening:** ≤2 short sentences before `1.`
2. **Sources:** tag a claim once when from email, document, text, or in person. Never invent sources.
3. **Delta:** list only open items. "Also for the record" block = agreed items that must appear in the document.
4. **Document-shaped asks:** "please write in the order form: ..." over open-ended questions when signing or closing.
5. **Layers:** separate easily confused layers (license vs support, included vs excluded) as short sub-bullets.
6. **Banned phrases:** [references/style-guide.md](references/style-guide.md). `scripts/draft-lint.py` enforces.
7. **Never send** without explicit go-ahead. Drafts are files, not sent mail.

## Workflow

1. Read prior thread or notes.
2. List open items (scratch table; keep out of email).
3. Draft in skeleton.
4. Save durable drafts at `scripts/draft-path.sh TOPIC` (`draft-<topic>.md`).
5. `scripts/draft-lint.py FILE`. Exit 1 lists `{line, rule}`. Fix each; rerun until 0.
6. Show path. Wait for send go-ahead.

## Config

JSON. Read only from `--config PATH` → `$AI_SKILLS_EMAIL_CONFIG` → `~/.config/ai-skills/email-style.json`.

| Key | Meaning |
|---|---|
| `greeting` | Required greeting word, e.g. `Hi`; checked at start of first body line |
| `closings` | Accepted closing lines, e.g. `["Thanks,"]` |
| `signature` | Name line expected after closing |
| `phone` | Number expected after closing (digits compared) |

- Missing config: signature, phone, closing, greeting checks skipped with stderr warning.
- `--skip RULE[,RULE]` drops rules by prefix. `--recipient-elsewhere` allows time-zone labels.

## Self-Check

- [ ] Sender would say this out loud to recipient?
- [ ] Scannable in 30 seconds?
- [ ] Sources tagged without re-teaching?
- [ ] Clear "what goes in the document" asks?
- [ ] Lint exits 0?
