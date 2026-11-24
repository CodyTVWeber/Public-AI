# Docs: current state or dated snapshot

Every doc is one of two kinds. Pick at creation; never mix.

| Kind | Describes | Filename | Edited later? |
| --- | --- | --- | --- |
| **Current** | How things are now | Stable name: `architecture.md`, `README.md` | Yes. Rewrite in place so it stays true. |
| **Dated** | How things were on one date | `YYYY-MM-DD-<slug>.md`, in a `log/` or topic folder | No. Typos only. Corrections and supersession are a new dated doc. |

Default is **Current**. History, decisions, plans, postmortems, meeting notes, reviews, benchmarks, and migration records are **Dated**.

## Current docs

- Present tense, true today. Describe the system as it is, never as it changed.
- Banned: time-relative words. `now`, `new`, `old`, `previously`, `no longer`, `used to`, `recently`, `currently`, `soon`, `legacy`, `deprecated in favor of`, `as of v…`, `was changed`, `we switched`, `after the migration`.
- A change updates the sentence. It does not append "Update:" or strike text through.
- If the old state matters, write a dated doc for it and link to it.
- Stale means wrong. Delete what no longer holds; do not annotate it.

## Dated docs

- Filename date is the date the content is true.
- First lines: `Date: YYYY-MM-DD` and, when it replaces one, `Supersedes: <path>`.
- Written as if on that date: facts stated in the present tense of that date, anchored with `As of YYYY-MM-DD`. No hindsight, no "later we found".
- Never rewritten to match the present. A reader browsing the folder in date order sees a log of what was true when.
- Superseded by a new dated doc that links back. The old file stays.
- Other docs link to a dated doc as evidence, never as the source of current truth.

## Choosing

| Question | Answer |
| --- | --- |
| Should a reader trust this as true today? | Current |
| Is it a record of a moment, decision, or event? | Dated |
| It is both | Current doc states the fact; dated doc holds the record; current links to dated |

## Enforcement

- `lint-docs.sh [BASE]` (shipped by `setup-repo`) fails on time-relative words in changed Current docs and on any edit to an existing Dated doc beyond whitespace.
- Review check: a Current doc that reads like a changelog is a Dated doc in the wrong place.
