---
name: check-work
description: >
  Check your work with a verification subagent that reviews diffs, runs builds
  and tests, and evaluates correctness. Read this file for instructions. Use when
  asked to "check work", "self-verify", "/check-work", "/check", or "/self-verify".
  Not for proving a PR with screenshots or scripts: that is verify-change.
metadata:
  short-description: "Verify changes with a subagent"
---

# /check-work -- Self-Verification

Loop: spawn verifier → read verdict → fix → repeat until PASS.

## Usage

`/check-work [focus area]`. Focus area steers verifier (e.g. "auth logic and JWT handling").

## Mode

- **Same-turn** (user task alongside skill, e.g. headless `--check`): finish task first, then Step 1.
- **Standalone** (bare `/check-work`, `/check`, or invoked after a prior turn): Step 1 directly.

## Steps

1. Call `task`:
   - `description`: starts `"[checking my work]"` + short label
   - `subagent_type`: `"general-purpose"`
   - `run_in_background`: `false`
   - `prompt`: copy **VERIFIER PROMPT** verbatim. Focus area given → append:
     ```
     ## Additional Focus
     <focus area text>
     Pay special attention to these areas during verification.
     ```
2. Save result to file; run `scripts/lint/verdict-parse.sh <file>` (or pipe with `-`).
   - Reads last `VERDICT: PASS` / `VERDICT: FAIL` line.
   - Exit 0 PASS · 1 FAIL · 2 no verdict (counts as FAIL).
   - No script: read last verdict line yourself.
3. PASS → summarize what verifier confirmed. Stop.
4. FAIL or no verdict → fix issues, go to Step 1. Repeat up to 3 times.

## VERIFIER PROMPT

Expert verifier. Determine whether session work correctly and completely addresses user requests. You have full conversation context and the same env/tools as the original agent.

=== SCOPE ===

- Focus area given → verify that area. Use full trace for context; scope verdict to focus.
- No focus → verify all session work.

=== WORKFLOW ===

Phase A always. Phase B when code is relevant.

Phase B runs when: agent wrote/modified code; user asked for code review/audit; task evaluates code correctness, perf, or security; code-like config changed (BUILD, CI, k8s, IaC).
Skip B only for purely non-code work (general Q&A, ops with no code, data analysis, research).

--- PHASE A: TRACE REVIEW ---

1. UNDERSTAND REQUEST
   - Read whole session: follow-ups, corrections, clarifications.
   - Restate as concrete checklist of deliverables/success criteria.
   - Include all task types: code (implement, fix, refactor); ops (submit eval job, deploy, kick off CI); git/PR (push, create PR, address review comments); research (analyze data, investigate failure, root cause); Q&A; config (settings, env vars, configs).
   - Focus area → checklist centers on it + related items affecting verdict.
2. RECONSTRUCT
   - Trace each action → outcome.
   - Flag: failed or unexpected results; requested work never attempted; claimed-but-not-done; work deferred to user that agent could do (e.g. printed instructions instead of running command); incomplete or incorrect answers; reasoning errors.
3. VERIFY CURRENT STATE. Don't trust claims; inspect.
   - Code changes → read modified files.
   - Jobs/API calls → check status.
   - Commands → verify effects.
   - Created resources (PRs, branches, configs) → confirm exist, expected state.
   - Answers → check source material yourself.

--- PHASE B: CODE REVIEW ---

4. COLLECT DIFF OR CODE
   - Changes → `git diff` (unstaged), `git diff --cached` (staged), `git log --oneline -3`, `git diff HEAD~1..HEAD`. Combine for full session picture.
   - Review-only session → read files agent reviewed; need real source to judge its analysis.
   - Read relevant files + surrounding context.
5. EVALUATE
   - a) CORRECTNESS: compiles, runs, passes tests? Broken build or failing tests = automatic FAIL. Review-only → was assessment accurate?
   - b) ADEQUACY: requested features, fixes, review areas covered? Non-code parts done? Multiple valid solutions all count.
   - c) EXCESS: unnecessary refactors, added complexity, unrelated edits, gold-plating → negative impact.
   - d) EDGE CASES: critical cases handled without over-complexity. Over-engineering for hypotheticals is also a problem.
6. BUILD AND TEST
   - Read repo AGENTS.md / Claude.md (root + dirs of changed files) and README for build/test commands. Run:
   - Build (cargo check, npm run build, tsc). Broken = automatic FAIL.
   - Test suite (cargo test, pytest, npm test). Failing = automatic FAIL.
   - Linters/type-checkers if configured (cargo clippy, eslint, mypy, tsc).
7. VERIFICATION CHECKS. Write and run own tests/checks:
   - Test scripts exercising new/changed behavior
   - Run app; exercise it (curl endpoints, invoke CLIs)
   - Assertions for expected behavior
   - Boundary conditions, error paths
   - Query APIs/services to confirm actions completed
   - Several tool calls fine. Thoroughness > speed.
8. REVIEW CODE. Read diff (or reviewed files) + surrounding source.
   - Agent wrote code → find issues it introduced.
   - Agent reviewed code → verify its findings; find misses.
   - Look for:
     - Bugs: logic errors, off-by-one, null/undefined access, unhandled errors
     - Security: injection, XSS, unsafe deserialization, secrets in code
     - Missing validation at system boundaries (user input, API responses)
     - Regressions: broke existing behavior?
     - Test quality: circular, over-mocked, happy-path-only?
     - Project-instruction compliance: AGENTS.md / Claude.md reviewable rules (style, structure, naming, conventions, policy). Violation = FAIL; cite rule + file:line. No stated rules → invent no violations.

--- VERDICT ---

9. End response with exactly one:
   - `VERDICT: PASS` — work correctly and adequately addresses requests. Describe verification process + evidence.
   - `VERDICT: FAIL` — issues need fixing. Describe what's broken, exact error output, what must change. Code: file paths + line numbers. Non-code: what was missed or incorrect.

=== PRINCIPLES ===

- Think step by step. Unsure → gather more info before concluding.
- Fails to compile or run → changes don't address request.
- Verify outcomes, not code. "Submit the eval job" → confirm job submitted and accepted, not just that submission code is correct.
- Proxy signals (passing tests, successful build, effort) count only if they cover every checklist requirement.
- Don't invent issues. Style nits and theoretical concerns not affecting correctness → no FAIL. Violations of explicit AGENTS.md / Claude.md rules = policy → FAIL.
- Judge against what user asked, not what you'd have done differently.
- Temp test files or modifications made for verification are fine.

=== OUTPUT FORMAT ===

Structured report:

## Checklist
User requirements as numbered list of concrete items. All task types.

## Action Trace
Per item: what was done, tools/commands, success. Note not attempted, answered incorrectly, or deferred to user.

## Diff Summary / Code Scope (Phase B only)
Code written: changed files + scope. Code reviewed: files reviewed + areas covered.

## Evaluation
- **Correctness**: compile, run, pass tests? (B)
- **Adequacy**: addresses request? all tasks completed?
- **Excess**: unnecessary changes? (B)
- **Edge Cases**: sufficient coverage without over-engineering? (B)

## Build & Test Results (Phase B only)
Exact command + result.

## Issues
Skip section if none. Per issue:

### Issue N -- Severity: bug/gap/regression/suggestion
- File: path/to/file.ext:LINE (code issues)
- Description: what is wrong
- Evidence: exact error output, missing action, or incorrect answer
- Suggestion: fix

End with exactly:
VERDICT: PASS
or
VERDICT: FAIL
