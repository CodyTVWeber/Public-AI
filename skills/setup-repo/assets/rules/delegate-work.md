# Delegate work

Strong, expensive models (orchestrator, lead, reviewer) decide; cheaper workers do the volume.

| Task | Who |
|---|---|
| Tiny write: one or few lines, a memory/state note | Lead |
| Targeted read: known file, symbol, or range | Lead |
| Review, decision, plan | Lead |
| Small or larger write | Reused worker |
| Widespread read: multi-file search, sweep | Reused worker |
| Test runs, lint, git work | Reused worker |
| Independent, disjoint slices | Parallel workers, one per slice |

- One long-lived worker per stream of work: resume or message it; never spawn a fresh one per step, never do the work inline
- Parallel workers only when scopes are disjoint and independent
- Worker report = lead's input: verify key claims against the source; never paste raw dumps into replies or docs
- Brief each worker with: goal, scope, constraints, report shape
