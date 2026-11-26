# align

AI-agnostic skill: align with the human on a task or document before planning. It writes a spec, dated ADRs, a glossary and a one-page alignment brief under `docs/align/<topic>/`, reusing related docs.

Used alone or as phase A0 of [plan-implement-review-watch](../plan-implement-review-watch/) (`/apirw`, or `phases=align,plan,…`). [write-plan](../write-plan/) runs `scripts/assess.sh` and offers it for large, vague work.

## Install

Symlink or copy this directory into the agent's skills folder. `SKILL.md` points to `align.md`.

## Invoke

- `/align <task or document>`
- "Get aligned on …"
- Offered by `write-plan`; first phase in `/apirw`

## Layout

| Path | Holds |
|---|---|
| `align.md` | playbook |
| `assets/templates/` | `spec.md`, `adr.md`, `glossary.md`, `alignment.md` with `{{fill-ins}}` |
| `references/figma-fidelity.md` | design frame check and authority levels |
| `scripts/` | `assess.sh`, `find-related-docs.sh`, `new-doc.sh`, `check-align.sh`, `tests/` |

Run all tests: `scripts/tests/run-all.sh` in the repo root.
