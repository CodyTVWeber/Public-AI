# Repo front door

Date: 2026-11-28
**Branch:** `cursor/repo-front-door-2949`
**Status:** implemented

## Context

Align: `docs/align/repo-front-door/` (uncommitted). `assess.sh`: size small, vagueness low. The user asked to apply the comparison findings.

This pack has skills, rules, and checkers, and no root README. Skill names mix the daily loop, one-line aliases, experimental skills, and personal tools. Test-first work, bug diagnosis, and module shape are judgment, and no skill holds that judgment.

Read from: `origin/main` `8d9ccc9e8cbe958c90465b8adcdf1ffd9f7d6c60`.

No runtime change: monitoring skipped.

## Terms

| Term | Meaning |
| --- | --- |
| front door | Current root `README.md` |
| catalog | `skills/CATALOG.md`, one row per skill |
| design skill | Prose practice a script cannot pass or fail |
| alias | A name in the manifest `aliases` array |
| default install | Manifest `core` plus `support` |

## Decisions

| Decision | Choice | Rejected |
| --- | --- | --- |
| Front door | Root README plus a checked catalog | Extending `AGENTS.md` only; generating the pitch from frontmatter |
| Design skills | Manifest class `design`. Not in `core` or `support` | Adding them to the default install |
| Aliases | Stay. Stay opt-in | Deleting or renaming them |
| Distribution | Clone, `AI-setup`, or `setup-repo` | A plugin marketplace |
| `/apirvw` aliases | Range: `idea-to-production` (spells the range; the way in) and `idea-to-prod`. Verbs: `/build` (nothing to working), `/deliver` (ends shipped), `/advance` (one station forward). `/apirvw` is the power-user shortcut | Renaming `/apirvw`. Any alias name outside this set |

## Alias names

`/idea-to-production` spells the range and is the primary way in. `/idea-to-prod` is the short form of that same range. The verb names are `/build`, `/deliver`, and `/advance`. `/apirvw` stays the skill name and is only the power-user shortcut.

Skill files and `skills/CATALOG.md` stay unchanged: these names are not catalog rows, and no catalog row needs a rewrite to match this decision.

## Why this approach

The pitch is judgment, so a person writes the README. The name list is mechanical, so a script fails when `SKILL.md` names, the manifest, and the catalog disagree. Design skills stay out of the default install so the installed surface does not grow while the catalog explains it.

## Concrete steps

1. Add manifest arrays `design`, `experimental`, and `other`. Leave `core`, `support`, and `aliases` unchanged. `design` = `codebase-design`, `diagnosing-bugs`, `start-here`, `tdd`
2. Add `scripts/lint/check-skill-catalog.sh`. Name = frontmatter `name`, else the skill directory basename. Exit 1 unless the six classes partition those names and `skills/CATALOG.md` has one row `| \`name\` | class |` per name. Test in `scripts/tests/check-skill-catalog.test.sh`
3. Write `skills/CATALOG.md` and root `README.md` (install, `/start-here`, four failure modes, link to the catalog and to `AGENTS.md`)
4. Add the four design skills. Body about 60 lines, telegraphic, present tense. `start-here` routes; it says `apir` is not an alias (`pir` after align, `apirw` when watch is included)
5. One line each in `implement`, `review-code-quality`, and `review-tests`: load the design skill when it is installed
6. Run the catalog check from the pre-commit hook when the script is executable
7. One row in the `AGENTS.md` script table for the catalog check

## Acceptance criteria

- AC-1: Root `README.md` names install, `/start-here`, and a failure-mode table
- AC-2: Catalog lists every skill name once, class matching the manifest
- AC-3: Catalog script exits 0 here and exits 1 on a fixture that drops a name
- AC-4: The four design skills exist and are the manifest `design` array
- AC-5: `core` and `support` are unchanged
- AC-6: `implement`, `review-code-quality`, and `review-tests` name the design skill to load when installed

## Risks

- (non-blocking) A `core+design` install set can wait

## Out of scope

- Plugin marketplace, newsletter, or skills.sh listing
- Deleting aliases
- A checker for module depth, seam choice, or test quality
- Edits under `skills/experimental/`
- Changing which names `setup-repo` links by default

## Manual verification

- `scripts/lint/check-skill-catalog.sh`
- `scripts/tests/check-skill-catalog.test.sh`
- `scripts/lint/lint-docs.sh` on the branch
- `skills/setup-repo/assets/scripts/code-quality-check.sh` on the catalog shell script
