Build a self-contained animated HTML that explains a hard-to-hold-in-head bug or code path to a non-engineer. Output = before/after simulation, not diagram or prose wall.

- Use for bugs that must be *seen*: race, rollback, cache clobber, ordering bug.
- Not for code a normal explanation covers.

## Step 0 — Verify diagnosis against source

- Don't visualize an unverified bug. Re-read exact files and lines before writing HTML.
- Don't trust summaries, including your own conversation summaries.
- Fix exists → read actual diff, not a description of it.

## Step 1 — Pin every number

Most-skipped step. Skipping it produces misleading visualizations.

- Concurrent N, item counts, before/after outcome counts: grep real constant or limit (config constant, loop bound, batch size).
- Never use round dramatic defaults ("10-15") when real ceiling is smaller and checkable.
- No hard limit → say so in subtitle: "shown here with N for clarity; the real number varies".
- State if animated worst case is actual guaranteed worst case or plausible-but-unverified. Concurrent interleaving is often non-deterministic from static reading; say so.

## Step 2 — Copy `templates/explainer.html` and fill

Layout: two side-by-side panels (before/after), each with animated item list, scrolling log, summary line. Code-diff section below (real before/after snippet). Footer links plan/investigation doc.

| Placeholder | Fill |
|---|---|
| `{{TITLE}}`, `{{SUBTITLE}}`, `{{SCENARIO_CAPTION}}` | Subtitle carries Step 1 caveat if applicable |
| `{{BEFORE_DESC}}`, `{{AFTER_DESC}}` | 1-2 plain sentences naming real function/variable |
| `{{FILE_PATH}}`, `{{CODE_BEFORE}}`, `{{CODE_AFTER}}` | Actual diff, not paraphrase. Unwritten fix → label "proposed", not shipped. |
| `{{FOOTER}}` | Link to plan/investigation doc |
| `ITEMS`, `FAIL_INDEX`, `runAnimation()` | Step 3 |

## Step 3 — Narrative matches real execution order

Animation shows *why* the bug happens. Usually ordering: later failure clobbers earlier success, stale snapshot, race.

- Siblings resolve out of order → show it. Fast ones first; slow/failing one last, mirroring real trigger.
- Suspiciously clean order rarely matches the real bug.
- Log lines use real names (`onError`, `setQueryData`, actual query key), not placeholders. Keeps diff and animation one artifact.

## Step 4 — Verify before showing anyone

Common failure: `buildList()` builds item DOM ids with one prefix; `setStatus()`/`markReverted()` look up another (e.g. container id `'before-list'` vs intended prefix `'before'`). Throws on first status update; animation dies silently; buttons stay disabled. Page loads fine and log prints a line or two, so it looks like partial progress.

1. Run `scripts/lint/lint-explainer.sh <file.html>` (PostToolUse hook runs it on written explainers). Checks: leftover `{{TOKEN}}`, `getElementById` literal with no matching `id=`, unbalanced `<script>`. No script → check by hand.
2. Grep every constructed id (`buildList`, `resetAll`) against every `getElementById` with constructed id (`setStatus`, `markReverted`). Confirm identical strings for `before-*` and `after-*`.
3. Trace `runAnimation()` by hand: every `setStatus`/`markReverted`/`log` call has right argument count and order; loop reaches every item (no early return leaving items `pending`).
4. If you can open the file in a browser and click "Run simulation," do it. Static tracing misses some bugs. High stakes → independent read (other model, fresh context) on narrative and JS.
5. Never assert "runs correctly" unless executed or independently traced. Same-context static read = weakest verification.

## Step 5 — Save

Next to the plan/investigation doc it illustrates, e.g. `docs/plans/<year>/<month>/<same-date>_<same-topic>.html` beside the `.md` plan. Not in this skill's repo: `example/` holds this skill's own worked examples only.

## Non-Goals

- Not a general diagramming tool. No order/timing/state → static diagram or plain explanation is faster and more honest.
- Not a test. Regression test is proof; this is for human understanding.
- No invented numbers, outcomes, or snippets. Every number and before/after line traces to code you read.
