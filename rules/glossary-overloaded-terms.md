# Glossary for overloaded terms

Word meaning different things across product parts (per program, vertical, tenant, or product era) → glossary entry. Agents and readers match on names; code named for one meaning holding the other → wrong build that still looks right.

- Keep `docs/glossary.md`; one line in repo agent file points to it
- One entry per overloaded term: each meaning, where it applies, unit per layer (UI, API, storage, external systems)
- List misleading code names: types, functions, routes named for one meaning that hold the other
- Add entry in same change that introduces second meaning
- Plans and tickets touching term: link entry, state which meaning they use

```markdown
## Region
| Scope | Means | UI | API | Stored |
|---|---|---|---|---|
| Product A | one store | store | store id | store id |
| Product B | id + name + 1..N stores + map shape | region | region id | store-id list |

Misleading names: `RegionService`, `getRegion()` return store lists (Product A era).
```
