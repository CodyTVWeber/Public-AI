# Muscles and skeleton

Deterministic systems are the **skeleton**: scripts, linters, CI jobs, git hooks, analyzers. They take the brunt of compute. AI is the **muscles**: flexible, indeterministic glue that connects rigid parts. Maximize skeleton coverage to minimize token spend.

## Split

| Skeleton | Muscles |
|---|---|
| Math, counts, diffs, grep, lint, size, order | Judgment a script cannot encode |
| Repeatable, cheap, same result every run | Glue between rigid tools; one-off synthesis |
| CI, git hooks, PostToolUse analyzers | Write, wire, and refine those checks |

Never spend tokens on work a script can finish in milliseconds. Work that can be a script becomes a script before the next similar task.

## Wrap scripts

AI still writes skills, rules, and hooks. Each names a script or CI job for heavy analysis; the AI layer adds judgment on top.

| Layer | AI owns | Script owns |
|---|---|---|
| Rule | Floor, when it fails, who judges the gap | Thresholds, parse, pass/fail |
| Skill | When to run, how to read output, next action | Analysis, catalogs, diffs |
| Hook | When it fires, fail vs note | The check it calls |
| CI | Required jobs; same scripts as local | Identical pass/fail |

Pattern: artifact → script → findings → AI judges only gaps ([deterministic-checks.md](deterministic-checks.md)). Point the artifact at the script; never re-implement the analysis.

## Examples

| Work | Script | AI on top |
|---|---|---|
| Lint, comments, nesting, function size, call order | `code-quality-check.sh` | Extraction boundary, names vs docs |
| MR size | `check-mr-size.sh` | How to slice the concern |
| Docs kind | `lint-docs.sh` | Which facts belong in which doc |
| Script language · copy drift | `check-languages.sh` · `check-copies.sh` | — |

## Feedback loop

1. Write the script. Point the skill, rule, or hook at it. Hook the same check into CI or local hooks
2. Run the script; its result is the decision ([deterministic-checks.md](deterministic-checks.md))
3. Poke findings: false positive, miss, or threshold noise → fix the script, not the one case
4. Repeat until the skeleton covers the mechanical part; AI keeps only judgment

Don't: re-derive a count the script printed · eyeball lint a script already ran · grow a skill with analysis the script should own
