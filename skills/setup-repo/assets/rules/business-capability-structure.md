# Business-capability structure

Top folders name spoken business domains. Nested folders inherit that domain. Technical layers are not the tree.

| Place | Name |
|---|---|
| Top folder | A domain a person already says out loud, or a generic kit extracted from `shared/` |
| Nested folder | Same domain, narrower |
| Forbidden at top | `controllers/`, `services/`, `models/`, `utils/`, `helpers/`, `common/`, `components/` |

One task is not a domain. Do not invent a top-level name a person does not already say.

## DRY

Occurrence = distinct consumers of the same part (load sites). Similar-looking files are not one part. Do not lift coincidental lookalikes.

| Consumers | Action |
|---|---|
| 1 | Leave it. No empty `shared/` |
| 2 | Guideline: lift into that scope's `shared/` |
| 3 | Near-hard lift into that scope's `shared/` |

Lift to the nearest common parent of those consumers.

`shared/` uses business-centric names and may nest (`shared/auth/` can hold its own `shared/`). No depth cap. Deep is fine when the domain is large; fewer levels is better.

| Signal | Action |
|---|---|
| Folder is crowded (hard to scan) | Group into narrower child folders. File count, not depth |
| `shared/` keeps growing | Smell: grouping is off, or a generic kit is hiding in it |

Extremely generic kits (a design system, or any other intricate generic system) grow inside `shared/` first. Once they have a shape, extract to their own top folder so `shared/` does not bloat.

## Agents

Lift. Never sink. Humans or a later script may sink; agents do not.

## Thin structure rules

This file is the parent. Later files name domains, nodes, and edges only. They do not restate this file.

Enforced by: review.
