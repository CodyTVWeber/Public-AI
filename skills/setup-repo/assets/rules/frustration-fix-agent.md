# Frustration: fix the agent

Frustration, or a demand to work harder with no specific defect, means the agent's own setup is the likely fault. The same approach, pushed harder, is the wrong response. Put the setup tweak in place, then run cleanup rounds on the tree. The bad structure is why the miss repeats.

## Signal

| Signal | Looks like |
|---|---|
| Frustration | Repeated correction, exasperation, annoyance at the same miss |
| Vague harder | "Work harder", "do a better job", "be more thorough" — no concrete defect, file, or next step |
| Partial fix | "You only change some of the values", "the same mistake everywhere" |

A named defect still gets fixed. Frustration beside it still fires this rule.

## Likely levers

| Lever | Tweak |
|---|---|
| Rules | Missing or wrong always-on rule for this miss |
| Skills | No playbook, or the playbook was not followed |
| Hooks | Nothing catches the bad output before it lands |
| Model | A different model fits this kind of work |
| Effort | Raise or lower effort. Longer grinding is not effort |
| Strategy | Different split, tool, or order of work |
| Guidance | Clearer instructions, a reference screen, or the terms for the target |
| Setup | `setup-repo` never applied, so the floors that stop one-off copies are absent |

## What the words mean

| They said | Avenue |
|---|---|
| Better UI, no defect | They can see a target. Clarify the miss. Get a reference screen (a known multi-choice, Duolingo-shaped). In the reply, name the terms for that target so the next ask is precise. Naming terms is not teaching mode |
| Same miss, only some sites change | DRY failed. One-off copies of pages, components, or values, so a search misses call sites. A tighter search-and-replace can finish this pass. The lasting fix is many extractions: shared components, values, and functions, so one edit hits every call site |
| Human stops reading the code | Files are huge and grouped so links stay hidden. Extract small objects. Domain first: by the business surface ([business-capability-structure.md](business-capability-structure.md); intake, results, help), then by role inside it (components, constants, functions, hooks). A technical bucket (every component in one folder) hides the links |

## Cleanup rounds

- Order: setup tweak first (rules, skills, hooks, model, effort, strategy, guidance, `setup-repo`). Then one or more passes over the tree that bad practice produced
- The pass is extraction and domain grouping across the app. A patch on one copy leaves the miss in place
- Tiny app: a few duplicated spots are tolerable
- Past that, each leftover bad decision multiplies the next. Complexity and the cost to undo it grow together. Tokens burn, and the agent makes more bad decisions
- A mostly sound app still grows that cost when the structure is a bit off

## Do

- Say the miss is likely the agent's setup. Name the levers and the cleanup the words point at
- Several plausible → list each avenue. Offer to make the ones the agent can make. Model and effort: propose them; the harness applies them
- A specific defect in the same message: fix that too, then the copies and the structure that made it repeat

## Don't

- Repeat the plan with more words, more retries, or a promise to be more careful
- Ask the human to design the agent's fix. Do clarify the product target, the reference screen, and the terms
- Treat the tone as something to soothe. It is evidence
- Patch one copy and call an app-wide miss done
