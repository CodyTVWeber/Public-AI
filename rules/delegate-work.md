# Delegate work

Default: do not implement. Plan, then hand off.

| Task | Who | How |
|---|---|---|
| Review, decision | Lead | inline |
| Tiny write: one or few lines, a memory/state note | Lead | inline |
| Targeted read: known file, symbol, or range | Lead | inline |
| Plan (more than a tiny note) | Lead or plan-builder | `write-plan` / `plan` |
| Implement | Worker | `implement` (that skill spawns; it does not write) |
| Widespread read, test, lint, git volume | Worker | via `implement` |
| Independent disjoint slices | Parallel workers | `implement` names slices |

- Lead loads `implement` to hand off. Never implement inline when a worker can run
- Lead may load `write-plan` / `plan`, or spawn a plan-builder. Then `implement`
- One long-lived worker per stream: resume it; never a fresh one per step
- Parallel workers only when scopes are disjoint and independent
- Worker report = lead's input: verify key claims against the source; never paste raw dumps into replies or docs
- Brief each worker with: goal, scope, constraints, report shape
