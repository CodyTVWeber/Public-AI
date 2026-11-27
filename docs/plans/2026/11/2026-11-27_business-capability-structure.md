# Business-capability structure rule

Date: 2026-11-27
**Branch:** `cursor/business-capability-structure-c759`
**Status:** draft

## Context

Codify the settled organization principle as one reusable current rule. Thin structure rules (skills tree, front-end, BFF, docs) and any later DAG lint inherit it; they are not this change.

`skills/setup-repo/assets/skills-manifest.json` is the skill-name inventory for `link-skills.sh`. It is not a home for a rule. The skills pack receives rules via `scripts/lint/copies.list` (`rules/*.md` → `skills/setup-repo/assets/rules/`).

Align: skipped (`assess.sh` size small, vagueness low).

No runtime change: monitoring skipped.

Read from: `origin/main` `875a354`.

## Why this approach

Technical buckets (`controllers/`, `utils/`) hide which job a file belongs to. Folders named for spoken domains are navigable without a legend, in a small pack and in a large host repo.

One generic rule, not four copies. Skills, front-end, BFF, and docs inherit it. Thin files name domains, nodes, and edges only.

Agents lift on repeat and do not sink or invent a domain from one task. The rule matches that behavior: 2 consumers = guideline, 3 = near-hard, lift to the nearest parent `shared/`. No depth cap; a crowded folder → group deeper (file count, not a fixed number). Growing `shared/` is a smell. Generic kits (a design system, or any other intricate generic system) grow in `shared/` then extract to their own top folder.

Same install path as other portable rules so `setup-repo` ships it with no special case. `skills-manifest.json` stays a skill-name list.

Settled content (no lint, folder moves, or sink automation in this change):

| Piece | Decision |
|---|---|
| Tree | Top folders = spoken business domains; nested folders inherit that context; not technical layers |
| DRY | Same part: 2 consumers = lift guideline; 3 = near-hard lift into that scope's `shared/` |
| Shared | Business-centric names; `shared/` may nest (`shared/auth/shared/…`). No depth cap |
| Nesting | Crowded folder → group deeper (file count, not a fixed number). Growing `shared/` is a smell |
| Generic kits | Grow in `shared/`; extract (design system or any intricate generic system) to own top folder |
| Agents | Lift; never sink. Do not invent a domain from one task |
| Occurrence | Count distinct consumers of the same part (load sites), not similar-looking files |

## Concrete steps

1. Add `rules/business-capability-structure.md` (current doc, ≤ ~40 lines, telegraphic). Must include: business-capability tree; 2/3 DRY; business-named recursive `shared/`; agents lift and never sink; never invent a domain from one task; occurrence = distinct consumers of one part; no empty `shared/` before a second consumer; technical buckets (`controllers/`, `utils/`) forbidden at the top. Parent of later thin structure rules: those files name domains/nodes/edges only.
2. `scripts/lint/check-copies.sh --fix` so `skills/setup-repo/assets/rules/business-capability-structure.md` matches.
3. `rules/README.md`: table row after `frustration-fix-agent.md`. One line: business-capability tree; 2/3 DRY; agents lift, never sink. Enforced by: review.
4. `AGENTS.md` Rules: one bullet linking the rule, next to the frustration bullet (cleanup already says group by domain).
5. `AI-setup/AGENTS.md`: one sentence under Frustration pointing at the rule (domain grouping). `AI-setup/README.md` Behavior table: one row.
6. `rules/frustration-fix-agent.md` "Domain first" cell: link the new rule. Copy stays identical (`check-copies.sh`).
7. Do not edit `skills/setup-repo/assets/skills-manifest.json`.
8. `scripts/lint/check-copies.sh` exits 0. `scripts/lint/lint-docs.sh origin/main` exits 0.

## Risks

- Agents treat 2 as a hard lift and mint fake domains. Rule text must say 2 is a guideline, 3 is near-hard, and one task is not a domain.
- "Occurrence" gamed as file-similarity. Rule must define consumer count of the same part.

## Out of scope

- DAG lint / `check-structure.sh`
- Moving `skills/` into `development/align|plan|review`
- Thin inheritor rules (`structure-skills`, front-end, BFF, docs)
- Sink script or host-loader recursion
- Edits to `skills-manifest.json`

## Test checklist

- [ ] Rule states tree, 2/3, recursive business-named `shared/`, lift-never-sink, no domain from one task
- [ ] Canonical and assets copy are byte-identical
- [ ] Pointers in `rules/README.md`, `AGENTS.md`, `AI-setup/AGENTS.md`, `AI-setup/README.md`
- [ ] `skills-manifest.json` unchanged
- [ ] `check-copies.sh` and `lint-docs.sh origin/main` exit 0
