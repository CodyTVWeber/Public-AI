# Email style guide

## Structure

1. Header: `**To:**`, `**Cc:**` (omit if none), `**Subject:**`
2. Greeting with recipient's first name
3. Purpose: one short sentence, or straight to `1.`
4. Nested outline, 1-4 layers
5. Scope: decisions still open or just resolved. Undisputed items stay out.
6. Close: 1-2 lines, plain, offer a call if useful. Closing and signature per user config.

## "More Outline"

| Means | Does not mean |
|---|---|
| Deeper nesting | Longer email or more flat bullets |
| Hierarchy: decision, terms, caveats | Repeating settled scope for completeness |

## Source Tags

| Source | Phrase |
|---|---|
| Their email | "your Monday email" |
| Own email | "my earlier email" |
| Document or quote | "the pricing sheet", "the renewal quote" |
| In person | "on the call you also mentioned" |
| Text message | "your text" |

One tag per claim. Never stack citations on every line.

## Banned Phrases

| Phrase | Why |
|---|---|
| "hope you're well", "hope this finds you" | Filler opener |
| "thanks so much" | Gushing |
| "please don't hesitate" | Stock close |
| "as outlined above" | Points back instead of saying it |
| "as discussed in our correspondence" | Rehash cue |
| "pursuant", "aforementioned" | Legal memo |
| "leverage", "ensure alignment" | Corporate filler |
| "I went back and reviewed" | Narrates effort. Label and nest instead. |

Also rejected: emoji, time-zone labels, walls of flat bullets, wiki-style lectures with no ask, numbered lists of pure facts with no ask.

## Distinctions as Sub-Bullets

```markdown
1. **Coverage.** One lead sentence.
   - **Layer A (included):** detail
   - **Layer B (excluded):** detail
   - **Layer C (easy mix-up):** detail

   Please put both in the order form as separate lines:
   - (a) item
   - (b) item
```

## Example

```markdown
**To:** Vendor A
**Subject:** Remaining items before renewal

Hi Vendor A,

Thanks for the revised quote; we can move forward.

1. **Seat count**
   - Renew at the quoted count
     - Seats stay as listed
       - No added seats
       - No price change

2. **Support tier**
   - Covered as described in the pricing sheet
     - No separate support add-on needed

We will return the signed order form today.

Thanks,
Sender Name
```
