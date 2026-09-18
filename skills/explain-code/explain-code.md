Build a self-contained, animated HTML that explains a hard-to-understand bug or piece of code to a
non-engineer stakeholder — a before/after simulation, not a diagram or a wall of prose.

Use this when someone needs to *see* a bug happen (a race condition, a rollback, a cache clobber,
an ordering bug) rather than read about it. Do not use this for straightforward code that a normal
explanation already covers — this is for the genuinely hard-to-hold-in-your-head parts.

## Step 0 — Confirm the diagnosis is real, not hypothesized

Do not build a visualization for a bug you haven't verified against the actual source. If the bug
was diagnosed in this conversation, re-read the exact files/lines involved yourself before writing
any HTML — don't trust a summary, even your own from earlier in the conversation. If a fix already
exists, read the actual diff, not a description of it.

## Step 1 — Pin down every number you're about to show

This is the step most likely to get skipped, and skipping it is what produces a misleading
visualization. Before picking how many items/tasks/requests to animate, or what the "before" and
"after" outcome counts are, grep the real code for the actual constant/limit:

- If the narrative involves "N things happening at once," find the real N (a config constant, a
  loop bound, a batch size) — don't default to a round number that sounds dramatic ("10-15") when
  the real ceiling is smaller and checkable.
- If you can't find a hard limit, say so explicitly in the subtitle ("shown here with N for
  clarity; the real number varies") rather than presenting an invented number as fact.
- State whether the worst-case outcome you're animating is the actual guaranteed worst case, or a
  plausible-but-unverified one (e.g. exact interleaving/timing of concurrent operations is often
  not fully deterministic from static code reading alone — say so if that's the case).

## Step 2 — Copy `templates/explainer.html` and fill it in

Structure: two side-by-side panels (before/after), each with an animated list of items, a scrolling
log, and a summary line; a code-diff section below showing the real before/after snippet; a footer
linking back to the plan/investigation doc.

Fill in:
- `{{TITLE}}`, `{{SUBTITLE}}` (include the Step 1 caveat here if applicable), `{{SCENARIO_CAPTION}}`
- `{{BEFORE_DESC}}` / `{{AFTER_DESC}}` — one or two sentences each, plain language, naming the real
  function/variable involved
- `{{FILE_PATH}}`, `{{CODE_BEFORE}}`, `{{CODE_AFTER}}` — the *actual* diff, not a paraphrase. Copy
  real lines from the real diff/file. If you're describing a not-yet-written fix, label it clearly
  as proposed, not shipped.
- `ITEMS` and `FAIL_INDEX` in the script, and the `runAnimation()` narrative — see Step 3.

## Step 3 — Write the animation narrative to match real execution order

The point of the animation is to show *why* the bug happens, which usually hinges on ordering (a
later failure clobbering earlier successes, a stale snapshot, a race). Get the sequence right:

- If siblings resolve out of order (some fast, one slow), show that explicitly — resolve the fast
  ones first in the animation, then the slow/failing one last, mirroring the real trigger
  condition. A narrative where everything resolves in a suspiciously clean order rarely matches
  the actual bug mechanism.
- Log lines should reference real function/variable names (`onError`, `setQueryData`, the actual
  query key), not generic placeholders — this is what makes the "actual diff" section and the
  animation cohere as one artifact instead of two disconnected things.

## Step 4 — Verify before showing it to anyone

This template's most common failure mode: `buildList()` builds item DOM ids with one prefix while
`setStatus()`/`markReverted()` look them up with a different prefix (e.g. the container id
`'before-list'` vs. the intended prefix `'before'`). This throws on the very first status update
and silently kills the whole async animation — no visible error, buttons just stay disabled
forever. It's easy to miss because the page loads fine and the log panel may print a line or two
before it dies, making it look like partial progress rather than a hard stop.

Before considering the file done:
1. Grep every place an id string is constructed (`buildList`, `resetAll`) against every place
   `getElementById` is called with a constructed id (`setStatus`, `markReverted`) — confirm they
   produce identical strings for both `before-*` and `after-*`.
   Trace `runAnimation()` by hand, step by step, confirming every `setStatus`/`markReverted`/`log`
   call has the right argument count and order, and that the loop actually reaches every item
   (no early-return path that would leave later items in `pending` forever).
3. If you have a way to actually open the file in a browser and click "Run simulation," do that —
   static tracing catches most bugs but not all; get a second, independent read (another model,
   fresh context) on both the narrative accuracy and the JS correctness if the stakes warrant it.
   Do not assert "this runs correctly" unless you've either executed it or had it independently
   traced — a static read by the same context that wrote the file is the weakest verification.

## Step 5 — Where to save it

Save next to the plan/investigation doc it illustrates (e.g.
`docs/plans/<year>/<month>/<same-date>_<same-topic>.html` alongside the `.md` plan), not in this
skill's repo — this skill's `example/` directory is for *this* skill's own worked examples, not a
dumping ground for every visualization you generate for other projects.

## Non-goals

- Not a general diagramming tool — if the concept doesn't hinge on order/timing/state, a static
  diagram or plain explanation is faster and more honest than forcing it into this animated format.
- Not a substitute for tests. This is for human understanding; the regression test (if one exists)
  is the actual proof the bug is real and the fix works.
- Don't invent numbers, outcomes, or code snippets that aren't grounded in the real codebase —
  every number and every line of "before/after" code shown must trace back to something you
  actually read.
