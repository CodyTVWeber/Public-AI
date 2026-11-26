# Docs: current state or dated snapshot

Every doc is one kind. Pick at creation; never mix.

| Kind | Describes | Filename | Edited later? |
| --- | --- | --- | --- |
| **Current** | How things are now | Stable name: `architecture.md`, `README.md` | Yes. Rewrite in place to stay true |
| **Dated** | How things were on one date | `YYYY-MM-DD-<slug>.md`, in `log/` or topic folder | No. Typos only. Corrections and supersession = a dated doc |

Default: **Current**. History, decisions, plans, postmortems, meeting notes, reviews, benchmarks, migration records: **Dated**.

## Current docs

- Present tense, true today. Describe system as it is, never as it changed
- Banned: time-relative words. `now`, `new`, `old`, `previously`, `no longer`, `used to`, `recently`, `currently`, `soon`, `legacy`, `deprecated in favor of`, `as of v…`, `was changed`, `we switched`, `after the migration`
- Change updates the sentence. No "Update:" appends, no strikethrough
- Prior state matters → dated doc, linked
- Stale = wrong. Delete it; don't annotate

## Dated docs

- Filename date = date content is true
- First lines: `Date: YYYY-MM-DD`; if replacing one, `Supersedes: <path>`
- Written as of that date: present tense of that date, anchored `As of YYYY-MM-DD`. No hindsight ("later we found")
- Never rewritten to match present. Date-ordered folder = log of what was true when
- Superseded by a dated doc linking back. Superseded file stays
- Other docs link dated doc as evidence, never as source of current truth

## Choosing

| Question | Answer |
| --- | --- |
| Should a reader trust this as true today? | Current |
| Is it a record of a moment, decision, or event? | Dated |
| Both | Current doc states the fact; dated doc holds the record; current links to dated |

## Enforcement

- Write to this rule while editing. `lint-docs.sh [BASE]` (shipped by `setup-repo`) fails the edit and the check on time-relative words in changed Current docs, and on any edit to an existing Dated doc beyond whitespace
- Review check: Current doc reading like changelog = Dated doc in wrong place
