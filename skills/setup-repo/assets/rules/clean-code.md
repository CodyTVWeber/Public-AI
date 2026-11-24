# Clean code (portable floor)

**Scope:** all new code + every line you touch or move. Splitting without cleaning is not done.
Project rules may extend this file; this is the floor.

## Self-check before every commit (touched files)

1. No new comments ([ban-comments.md](ban-comments.md)); moved code carries fewer than it had
2. File ≤ ~200 lines (hard stop ~400); one responsibility; extract before growing
3. Function body ≤ ~40 lines of logic
4. Params: 0-1 ideal, 2 ok, 3 painful, 4+ → options object or split
5. Nesting ≤ 2-3; early return / guard clause over pyramids
6. Public API on top, helpers below; callers above callees
7. Non-trivial try/catch and log-and-throw branches live in named functions
8. Magic numbers → named constants
9. No parameter mutation: compute and return; the caller assigns. If mutation is the point, the name says so
10. Enum over boolean when the outcome has a name
11. One definition per business rule; never duplicate a predicate or allow-list
12. Names match their own docs; if they disagree, rename
13. Docs are current state or a dated snapshot, never a diff narrative ([docs-current-or-dated.md](docs-current-or-dated.md))

## Comments

Canonical: [ban-comments.md](ban-comments.md). Code you add or touch ships with no comments.
The pre-commit check blocks an added comment. Rename or extract instead.

Empty catch stays forbidden: call a named helper such as `ignoreOptionalFailure(err)`.

## Never-nester

| Prefer | Avoid |
|---|---|
| Early return / continue / throw | `if (ok) { huge block }` |
| Guard clauses | Deep if/else pyramids |
| Flat sequential steps | try inside if inside try |

## try/catch and fail-fast → named functions

A non-trivial `try`/`catch`, or a "log then throw / log then fall back" branch, belongs in a named
function that states the attempt (`readCachedProfile()`, `failToLoad(file)`). Orchestrators call
helpers; they do not host long try blocks or inline `?: run { ... }` chains.

## Parameters

Default: do not edit arguments. `const next = withTotals(order)`, not `order.total = …`.
Mutation is fine for setters and builders, but then the function name must read as "writes into
this argument".

## Docs describe the present

State how the system works now. "Retries use exponential backoff", not "this replaced the fixed
delay". No `STATUS:` banners. History belongs only in ADRs, dated docs (changelogs, postmortems)
and docs that say on their first line that they are historical. A plan still being worked from is
live: rewrite it in place as decisions change.

## Tests

- Assert what happens; no assertion for a scenario the code cannot produce (absence checks are
  fine when they guard a real risk, e.g. leaked secrets)
- No test for a case that does not exist and never will (removed feature, retired branch,
  impossible state): it always passes, so it pins nothing. Removing a feature deletes its tests; do
  not add a "now renders nothing / returns null" test for the removed case
- Consolidate: extend an existing test's setup before adding a new test
- Short names that still state the scenario; group by behavior
- Whole-object assertions over field-by-field
- Small factories with defaulted params next to their usage; no shared god setup

## Size exceptions

Generated code, type barrels, pure data tables, migrations, large fixtures. No mass refactors of
untouched files unless tasked. Touching a file leaves it smaller and quieter.

## Enforcement

- `code-quality-check.sh` (shipped by `setup-repo`) checks self-check items 1-5, 7-10 on the lines you change: after every edit (Claude Code `PostToolUse`), when the agent stops (`Stop`), and at git pre-commit (`--staged`). Errors block; warnings advise.
- Judgment stays with review: item 6 (callers above callees), 11 (one definition per rule), 12 (names match docs). Item 13 is `lint-docs.sh`.
- Thresholds are env vars (`CC_FUNC_WARN`, `CC_NEST_ERROR`, ...); `code-quality-check.sh -h` lists them. `CC_SKIP=1` and `CLEAN_CODE_SKIP=1` skip a run and say so on stderr; fix the code instead of skipping.
