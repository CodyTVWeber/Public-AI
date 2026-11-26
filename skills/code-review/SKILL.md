---
name: code-review
description: Run an extremely strict maintainability review for abstraction quality, giant files, and spaghetti-condition growth. Use for a deep code quality audit or an especially harsh maintainability review.
disable-model-invocation: true
---

# Strict Code Quality Review

Unusually strict review: implementation quality, maintainability, abstraction, codebase health.
Be **ambitious**. Hunt "code judo": behavior-preserving restructures that make code dramatically simpler, smaller, more direct. Not local cleanup.

## Core Prompt

Baseline (use verbatim):

> Perform a deep code quality audit of the current branch's changes.
> Rethink how to structure / implement the changes to meaningfully improve code quality without impacting behavior.
> Work to improve abstractions, modularity, reduce Spaghetti code, improve succinctness and legibility.
> Be ambitious, if there is a clear path to improving the implementation that involves restructuring some of the codebase, go for it.
> Be extremely thorough and rigorous. Measure twice, cut once.

## Non-Negotiable Standards

Apply baseline plus:

0. **Ambitious structural simplification.**
   - Not "a bit cleaner". Reframe so whole branches, helpers, modes, conditionals, layers disappear.
   - Prefer the solution that feels inevitable in hindsight.
   - Delete complexity > rearrange it.
1. **No PR pushing a file ≤1000 lines to >1000 lines** without very strong reason.
   - Strong smell by default. Extract helpers, subcomponents, modules, local abstractions.
   - Mechanical check: `scripts/lint/check-1k-cross.sh <base>` (exit 1 on hits; each hit = presumptive blocker). No script: count lines at base and head.
   - Diff crosses threshold → ask whether to decompose first.
   - Waive only with compelling structural reason + file still clearly organized.
2. **No random spaghetti growth.**
   - Suspicious of new ad-hoc conditionals, scattered special cases, one-off branches in unrelated flows.
   - "Weird if statements in random places" = design problem, not style nit.
   - Push logic to dedicated abstraction, helper, state machine, policy object, or module.
   - Flag changes making surrounding code harder to reason about, even if working.
3. **Clean the design, don't accept working-but-messy.**
   - Same behavior + cleaner structure → push cleaner version.
   - Prefer removing moving pieces over spreading complexity around.
4. **Direct, boring, maintainable over hacky or magical.**
   - Brittle, ad-hoc, or magic behavior = code-quality problem.
   - Skeptical of generic mechanisms hiding simple data-shape assumptions.
   - Flag thin abstractions, identity wrappers, pass-through helpers.
5. **Type and boundary cleanliness when it affects maintainability.**
   - Question unnecessary optionality, `unknown`, `any`, cast-heavy code.
   - Prefer explicit typed models or shared contracts over loose ad-hoc objects.
   - Silent fallback papering over unclear invariant → ask whether boundary should be explicit.
6. **Logic in canonical layer; reuse existing helpers.**
   - Flag feature logic leaking into shared paths, or implementation details leaking through APIs.
   - Prefer canonical utilities over bespoke one-offs.
   - Push code to right package, service, or module.
7. **Serialized orchestration and non-atomic updates = smells when cleaner structure is obvious.**
   - Independent work serialized without reason → ask about parallel.
   - Related updates can leave state half-applied → push atomic structure.
   - Don't over-index on micro-optimizations; flag avoidable orchestration complexity.

## Primary Review Questions

Per meaningful change:

- Code-judo move that makes this dramatically simpler?
- Reframe → fewer concepts, branches, helper layers?
- Improves or worsens local architecture?
- Branching added where an abstraction should exist?
- Cohesive module now more coupled, stateful, or harder to scan?
- Logic in right file and layer?
- File or component past healthy size boundary?
- Repeated conditionals signaling missing model or helper?
- Direct and legible, or special cases and incidental control flow?
- Abstraction earning keep, or just a wrapper?
- Casts, optionality, ad-hoc object shapes obscuring real invariant?
- Logic in canonical layer, or details leaked across boundary?
- Orchestration more sequential or less atomic than needed?

## Flag Aggressively

- Complicated impl where reframing deletes whole categories of complexity
- Refactors moving code without reducing concepts a reader holds
- File crossing 1000 lines due to PR, especially if new code is splittable
- New conditionals bolted onto unrelated paths
- One-off booleans, nullable modes, flags complicating control flow
- Feature logic leaking into general-purpose modules
- Generic "magic" hiding simple structure
- Thin wrappers or identity abstractions adding indirection
- Unnecessary casts, `any`, `unknown`, optional params muddying contract
- Copy-paste instead of extracted helpers
- Narrow edge-case handling mid busy function
- Refactors passing tests but less modular or readable
- "Temporary" branching likely to become permanent debt
- Bespoke helpers where canonical utility exists
- Logic in wrong layer or package
- Sequential async where independent work could run in parallel and be simpler
- Partial-update logic less atomic than necessary

## Preferred Remedies

- Delete a whole indirection layer rather than polish it
- Reframe state model so conditionals disappear, not get centralized
- Change ownership boundary → feature becomes natural extension of existing abstraction
- Special-case logic → simpler default flow, fewer exceptions
- Extract helper or pure function
- Split large file into focused modules
- Feature logic behind dedicated abstraction
- Condition chains → typed model or explicit dispatcher
- Separate orchestration from business logic
- Collapse duplicate branches into one clearer flow
- Delete wrappers not clarifying the API
- Reuse canonical helper instead of near-duplicate
- Explicit type boundaries → simpler control flow
- Move logic to package, module, or layer owning the concept
- Parallelize independent work when it also simplifies orchestration
- Restructure related updates atomically when partial state is hard to reason about

Don't settle for "maybe rename this" when the issue is structural. Don't settle for a cleaner version of the same messy idea when a plausible path to a much simpler idea exists.

## Review Tone

- Direct, serious, demanding. Not rude.
- Don't soften major maintainability issues into mild suggestions.
- Say so when code makes the codebase messier. Say so when a dramatic simplification was missed.

Example phrasings:

- `this pushes the file past 1k lines. can we decompose this first?`
- `this adds another special-case branch into an already busy flow. can we move this behind its own abstraction?`
- `this works, but it makes the surrounding code more spaghetti. let's keep the behavior and restructure the implementation.`
- `this feels like feature logic leaking into a shared path. can we isolate it?`
- `this abstraction seems unnecessary. can we just keep the direct flow?`
- `why does this need a cast / optional here? can we make the boundary more explicit instead?`
- `this looks like a bespoke helper for something we already have elsewhere. can we reuse the canonical one?`
- `i think there's a code-judo move here that makes this much simpler. can we reframe this so these branches disappear?`
- `this refactor moves complexity around, but doesn't really delete it. is there a way to make the model itself simpler?`

## Output Priority

1. Structural code-quality regressions
2. Missed dramatic-simplification / code-judo opportunities
3. Spaghetti or branching-complexity increases
4. Boundary, abstraction, type-contract problems hurting reasoning
5. File-size and decomposition concerns
6. Modularity and abstraction issues
7. Legibility and maintainability

Skip low-value nits when structural issues exist. Few high-conviction comments > long cosmetic list.

## Approval Bar

Don't approve just because behavior is correct. Approve only if all hold:

- No clear structural regression
- No obvious missed dramatic simplification
- No unjustified file-size explosion
- No obvious spaghetti from special-case branching
- No hacky or magical abstraction hard to reason about
- No unnecessary wrapper, cast, or optionality churn obscuring design
- No architecture-boundary leak or avoidable canonical-helper duplication
- No missed obvious decomposition that would materially help maintainability

Presumptive blockers (unless author justifies clearly):

- Incidental complexity preserved where a code-judo move would delete it
- File goes from <1000 to >1000 lines
- Ad-hoc branching tangles an existing flow
- Feature checks scattered across shared code
- Unnecessary abstraction, wrapper, or cast-heavy contract
- Duplicates an existing helper, or logic in wrong layer with clear canonical home

Conditions unmet → actionable feedback; push for cleaner decomposition.

## Tracker Comments

Tracker task (e.g. Asana): follow [`../plan-implement-review/references/tracker-comments.md`](../plan-implement-review/references/tracker-comments.md). It is canonical; don't copy it here.

- Read existing comments **before** review. They are source of truth for prior attempts.
- After verdict, post **one Review rN** comment (PIR round if known, else r1). No task → no comments.
