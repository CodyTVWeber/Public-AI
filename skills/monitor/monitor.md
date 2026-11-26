---
name: monitor
description: After a change is deployed to PROD, watch it for a set window and verify it works, shows no related error regressions, leaves the data correct, and every other checkable system looks right. Strictly read-only; reports a verdict and asks before any action. Use for "monitor the deploy", "watch prod after release", /monitor, or the last phase of plan-implement-review-watch.
argument-hint: "[window=1h] [cadence=10m] [env=prod] [plan=<path>] [baseline=<path>]"
---

# Monitor

Phase after [`watch`](../watch/watch.md). `watch` ends when the change is merged and deployed to PROD; `monitor` starts there and runs for a set window. Self-paced, read-only, one orchestrator.

## Args

| Arg | Default | Meaning |
|---|---|---|
| `window=` | `1h` | How long to monitor; any `<n>s\|m\|h\|d` |
| `cadence=` | `10m` | Time between ticks |
| `env=` | `prod` | Environment under watch |
| `plan=` | none | Path to the Monitoring plan (section or doc) |
| `baseline=` | none | JSON file of pre-deploy values `{signal: value}` |

Deployed-to-PROD proof is required: deploy link, or a version or commit visible in a health endpoint. Missing → ask once. Never monitor an undeployed change as if deployed. The window starts when the deploy completes.

## Hard rules (read-only)

- Write to nothing: no rollback, flag flip, redeploy, data fix, ticket, or message. Observing is the whole job
- Databases: read-only connections and `SELECT` only
- Cloud CLIs: before each command verify the identity or role is read-only; any other role → stop and report it
- HTTP checks: the repo's approved tool or a script's own HTTP client, never `curl`/`wget` (they prompt)
- `degraded` → stop the loop, report evidence and a recommended action (rollback, flag off, hotfix, keep watching), then ask the human. Never act
- No data is never healthy: the verdict is `unknown`

## Verdicts

| Verdict | Meaning |
|---|---|
| `healthy` | Every signal ok or warn |
| `degraded` | Any signal failed its rule |
| `unknown` | No fail, but a signal has no value, no baseline, or no available source |

## Playbook

1. Read the Monitoring plan (`plan=`, else the plan doc's section) and any acceptance criteria from the align spec. Signals table: signal · kind · criteria · source · query or command · baseline · threshold rule · cadence · failure means · action or owner. No Monitoring plan → build one from the diff and the plan with [`monitoring-plan.md`](assets/templates/monitoring-plan.md), then get the human's yes before the window starts
2. `scripts/check-plan.sh <plan>` → fix `violations[]` until exit 0
3. Discover sources in this session and mark each signal `available` or `manual` (see Signal map). A `manual` signal is reported, never silently skipped
4. Baseline: pre-deploy values from `baseline=` or the same queries run against the pre-deploy period. None exists → capture at tick 0 and mark the baseline `weak`. Write it with `scripts/log-entry.sh <log> baseline`
5. Plan the ticks: `scripts/window.sh --duration <window> --cadence <cadence> --start <deploy time>`. Self-paced: schedule each wake-up with the harness's scheduling or loop facility; never busy-poll
6. Each tick: collect every due signal into a CURRENT JSON, `scripts/compare.sh baseline.json current.json rules.json`, then `scripts/log-entry.sh <log> tick` with the compare output. A tick is ≤ 8 lines in chat; quiet ticks say one line
7. Stop at the window end, on `degraded`, or when the human says stop. Write `scripts/log-entry.sh <log> final`
8. Final report, ≤ 10 lines: verdict · window · signals table (ok/warn/fail/unknown) · evidence links · recommended action

## Signal map

| Kind | Checks | Typical source |
|---|---|---|
| works | Each acceptance criterion has an observable signal | Synthetic probe, API call, UI trace |
| error | Error rate vs baseline; first-seen error signatures (`forbid_new_keys`) | Error tracker, APM, logs |
| data | Row counts, null and duplicate rates, invariants, freshness, orphans | Read-only SQL |
| health | Health and readiness endpoints, version served | HTTP check |
| latency | p95 and throughput vs baseline | APM, metrics |
| queue | Backlog depth, job failures, dead letters | Queue console, job dashboard |
| alert | Monitors firing, incidents opened | Alerting tool |
| flag | Feature-flag state and rollout percentage | Flag service |
| downstream | Consumers and dependencies of the change | Their health, error rates |
| kpi | Business metrics the change should leave steady or move | Analytics, dashboards |
| probe | Synthetic user-facing journeys | Browser or API script |

## Rules file

`compare.sh` reads RULES as a JSON array built from the plan's threshold column: `{"name","kind","limit"|"value","warn","allow_noise_abs"}`. Kinds: `max_ratio`, `max_abs`, `min_abs`, `equals`, `forbid_new_keys`. `scripts/compare.sh -h` lists the semantics.

## Monitoring log

A dated doc ([docs-current-or-dated](../../rules/docs-current-or-dated.md)): `docs/monitor/YYYY-MM-DD-<slug>.md`, or the repo's convention. `log-entry.sh` creates it with the `Date:` header, appends entries during the run, and refuses writes after the `## Final` entry. Commit it only after the final entry; later corrections are a new dated log.

## Scripts

| Script | Use | Exit |
|---|---|---|
| `scripts/window.sh --duration 2h --cadence 10m [--start ISO]` | Tick schedule JSON, capped at 288 ticks | 2 usage |
| `scripts/compare.sh BASELINE CURRENT RULES` | Verdict and per-signal status | 0 healthy, 1 degraded, 3 unknown, 2 usage |
| `scripts/log-entry.sh LOG tick\|baseline\|final` | Append an entry from stdin JSON | 3 log frozen, 2 usage |
| `scripts/check-plan.sh PLAN.md` | Validate the Monitoring plan | 1 violations, 3 no file |

All print JSON on stdout and take `-h`.

## Never

- Act on a finding: recommend, then ask
- Treat a missing value, a failed query, or an unreachable source as healthy
- Read a prod secret or personal data into the log; record counts, rates, and signature names
- Extend the window or the cadence without the human saying so
