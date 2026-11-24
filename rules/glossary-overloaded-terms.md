# Glossary for overloaded terms

A word that means different things in different parts of a product (per program, vertical, tenant,
or legacy era) gets a glossary entry. Agents and new readers match on names; when code named for
one meaning holds the other, they build the wrong thing and the code still looks right.

- Keep `docs/glossary.md`; one line in the repo's agent file points to it
- One entry per overloaded term: each meaning, where it applies, and its unit at each layer
  (UI, API, storage, external systems)
- List code names that mislead: types, functions, or routes named for one meaning that hold the
  other
- Add the entry in the same change that introduces the second meaning
- Plans and tickets that touch the term link the entry and say which meaning they use

```markdown
## Region
| Scope | Means | UI | API | Stored |
|---|---|---|---|---|
| Product A | one store | store | store id | store id |
| Product B | id + name + 1..N stores + map shape | region | region id | store-id list |

Misleading names: `RegionService`, `getRegion()` return store lists (Product A era).
```
