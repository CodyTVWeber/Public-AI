---
name: email-style
description: Draft outbound email in a plain, scannable, human business voice - nested outline, delta-only, light source tags, document-shaped asks. Use when drafting or rewriting an email, when the user says /email-style, "sound like me", or "not AI-sounding".
argument-hint: "[topic or thread]"
---

# Email style

Ready-to-send markdown in a human business voice. Default shape is a nested outline, 1-4 layers deep.

## When to use

- Draft or rewrite any outbound email: vendor, client, partner, external mail
- User asks for "my voice", "not AI-sounding", "scannable"
- Not for internal logs, plans or debriefs; those follow [outline-output](../outline-output/)

## Shape

| Layer | Form |
|---|---|
| 1 | `1. **Label.**` numbered topics |
| 2-4 | Indented bullets; layer 4 is rare |

- "More outline" means deeper nesting where hierarchy helps, not more bullets or more words
- One idea per line; distinctions become sub-bullets, never a dense paragraph
- Only open topics: skip settled items that nobody is debating (delta only)

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

- `Cc` is omitted when empty
- Greeting, closing, signature and phone come from the user config ([Config](#config)); nothing personal lives in this repo

## Voice

| Do | Avoid |
|---|---|
| Warm but business; talk like a person | Legal memo, cold AI, gushing |
| Greeting + name, straight to purpose | Small talk by default, "hope you're well" |
| Contractions, plain words | "pursuant", "aforementioned", "leverage", "ensure alignment" |
| Tag sources lightly: "your Tuesday email", "on the call", "the renewal quote", "your text" | Re-teaching facts the reader already knows |
| Assume the recipient shares the sender's time zone; omit labels | Time-zone labels on times |
| Plain close, offer a call | "Please don't hesitate", "as outlined above", stacked softeners |

## Content rules

1. **Opening:** ≤2 short sentences before `1.`
2. **Sources:** tag a claim once when it came from email, document, text or in person; never invent sources
3. **Delta:** list only what is still open; an "Also for the record" block holds agreed items that must appear in the document
4. **Document-shaped asks:** "please write in the order form: ..." over open-ended questions when signing or closing
5. **Layers:** separate easily confused layers (license vs support, included vs excluded) as short sub-bullets
6. **Banned phrases:** see [references/style-guide.md](references/style-guide.md); `scripts/draft-lint.py` enforces them
7. **Never send** without the user's explicit go-ahead; drafts are files, not sent mail

## Workflow

1. Read the prior thread or notes, if any.
2. List what is still open (a scratch table; keep it out of the email).
3. Draft in the skeleton.
4. Save durable drafts at the path from `scripts/draft-path.sh TOPIC` (`draft-<topic>.md`).
5. Run `scripts/draft-lint.py FILE`; exit 1 lists `{line, rule}`; fix each, rerun until 0.
6. Show the path and wait for the send go-ahead.

## Config

JSON, read only from `--config PATH`, else `$AI_SKILLS_EMAIL_CONFIG`, else `~/.config/ai-skills/email-style.json`.

| Key | Meaning |
|---|---|
| `greeting` | Required greeting word, e.g. `Hi`; checked at the start of the first body line |
| `closings` | Accepted closing lines, e.g. `["Thanks,"]` |
| `signature` | Name line expected after the closing |
| `phone` | Number expected after the closing (digits compared) |

- Missing config: signature, phone, closing and greeting checks are skipped with a stderr warning
- `--skip RULE[,RULE]` drops rules by prefix; `--recipient-elsewhere` allows time-zone labels

## Self-check

- [ ] Would the sender say this out loud to the recipient?
- [ ] Scannable in 30 seconds?
- [ ] Sources tagged without re-teaching?
- [ ] Clear "what goes in the document" asks?
- [ ] Lint exits 0?
