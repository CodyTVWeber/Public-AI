# Clean code (portable floor)

**Scope:** all added code + every touched or moved line. Splitting without cleaning ≠ done.
Project rules may extend this; this is the floor.

## Self-check before every commit (touched files)

1. No added comments ([ban-comments.md](ban-comments.md)); moved code carries fewer than before
2. File ≤ ~200 lines (hard stop ~400); one responsibility; extract before growing
3. Function body ≤ the `CC_FUNC_SIZE` warn cap (default `b`: ~20 lines of logic)
4. Params: 0-1 ideal, 2 ok, 3 painful, 4+ → options object or split
5. Nesting ≤ 2-3; early return / guard clause over pyramids
6. Public API on top, helpers below; callers above callees
7. Non-trivial try/catch and log-and-throw branches live in named functions
8. Magic numbers → named constants
9. No parameter mutation: compute and return; caller assigns. If mutation is the point, name says so
10. Enum over boolean when outcome has a name
11. One definition per business rule; never duplicate a predicate or allow-list
12. Names match their own docs; if they disagree, rename
13. Docs are current state or dated snapshot, never a diff narrative ([docs-current-or-dated.md](docs-current-or-dated.md))

## Comments

- Canonical: [ban-comments.md](ban-comments.md). Added or touched code ships with no comments
- Pre-commit check blocks added comment. Rename or extract instead
- Empty catch stays forbidden: call named helper, e.g. `ignoreOptionalFailure(err)`

## Never-nester

| Prefer | Avoid |
|---|---|
| Early return / continue / throw | `if (ok) { huge block }` |
| Guard clauses | Deep if/else pyramids |
| Flat sequential steps | try inside if inside try |

## try/catch and fail-fast → named functions

Non-trivial `try`/`catch`, or log-then-throw / log-then-fall-back, lives in a named function stating the attempt (`readCachedProfile()`, `failToLoad(file)`). Orchestrators call helpers; no long try blocks or inline `?: run { ... }` chains.

## Parameters

- Default: do not edit arguments. `const next = withTotals(order)`, not `order.total = …`
- Mutation OK for setters and builders; function name must read "writes into this argument"

## Docs describe the present

- State how system works now: "Retries use exponential backoff", not "this replaced the fixed delay"
- No `STATUS:` banners
- History only in: ADRs, dated docs (changelogs, postmortems), docs whose first line says historical
- Plan still worked from = live: rewrite in place as decisions change

## Tests

- Assert what happens. No assertion for a scenario the code cannot produce (absence checks fine when guarding real risk, e.g. leaked secrets)
- No test for a case that never exists (removed feature, retired branch, impossible state): always passes, pins nothing. Removing a feature deletes its tests; no "renders nothing / returns null" test for removed case
- Consolidate: extend existing test's setup before adding a test
- Short names that state the scenario; group by behavior
- Whole-object assertions over field-by-field
- Small factories with defaulted params next to usage; no shared god setup

## Size exceptions

Generated code, type barrels, pure data tables, migrations, large fixtures. No mass refactors of untouched files unless tasked. Touching a file leaves it smaller and quieter.

## Enforcement

- Write to this floor while editing. `code-quality-check.sh` (shipped by `setup-repo`) checks self-check items 1-10 on changed lines: after every edit (Claude Code `PostToolUse`), when the agent stops (`Stop`), at git pre-commit (`--staged`). Errors fail that step; warnings advise
- Item 6 is `function-order` (warn): a caller below its callee, or a private helper above a public function in the same block. Cycles are skipped
- A body that is one `if` with no `else`, once the function reaches 8 logic lines, is `guard-clause` (warn)
- Judgment stays with review: item 11 (one definition per rule), 12 (names match docs). Item 13 is `lint-docs.sh`
- Function length profiles (`CC_FUNC_SIZE` or repo-root `.func-size` line `size: a|b|c`; default `b`). `CC_FUNC_WARN` / `CC_FUNC_ERROR` override the pair

| Profile | Warn | Error |
|---|---|---|
| `a` | 40 | 80 |
| `b` (default) | 20 | 40 |
| `c` | 50 | 100 |

- Other thresholds are env vars (`CC_NEST_ERROR`, ...); `code-quality-check.sh -h` lists them. `CC_SKIP=1` and `CLEAN_CODE_SKIP=1` skip a run and say so on stderr; fix the code instead of skipping
