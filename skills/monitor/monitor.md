---
name: monitor
description: After a change is deployed to PROD, watch it for a set window and verify it works, shows no related error regressions, leaves the data correct, and every other checkable system looks right. Strictly read-only; reports a verdict and asks before any action. Use for "monitor the deploy", "watch prod after release", /monitor, or the last phase of plan-implement-review-watch.
argument-hint: "[window=1h] [cadence=10m] [env=prod] [plan=<path>] [baseline=<path>]"
---

# Monitor

Phase after [`watch`](../watch/watch.md). `watch` ends when change is merged and deployed to PROD. `monitor` starts there, runs for set window. Self-paced, read-only, one orchestrator.

## Args

| Arg | Default | Meaning |
|---|---|---|
| `window=` | `1h` | Monitoring duration; `<n>s\|m\|h\|d` |
| `cadence=` | `10m` | Time between ticks |
| `env=` | `prod` | Environment under watch |
| `plan=` | none | Path to Monitoring plan (section or doc) |
| `baseline=` | none | JSON file of pre-deploy values `{signal: value}` |

- Deployed-to-PROD proof required: deploy link, or version/commit visible in health endpoint. Missing → ask once.
- Never monitor undeployed change as deployed. Window starts when deploy completes.

## Hard rules (read-only)

- Write nothing: no rollback, flag flip, redeploy, data fix, ticket, or message. Observing is the whole job.
- Databases: read-only connections, `SELECT` only.
- Cloud CLIs: verify identity/role is read-only before each command. Any other role → stop, report it.
- HTTP checks: repo's approved tool or a script's own HTTP client. Never `curl`/`wget` (they prompt).
- `degraded` → stop loop, report evidence + recommended action (rollback, flag off, hotfix, keep watching), ask human. Never act.
- No data is never healthy: verdict `unknown`.

## Verdicts

| Verdict | Meaning |
|---|---|
| `healthy` | Every signal ok or warn |
| `degraded` | Any signal failed its rule |
| `unknown` | No fail, but a signal has no value, no baseline, or no available source |

## Playbook

1. Read Monitoring plan (`plan=`, else plan doc's section) and acceptance criteria from align spec. Signals table columns: signal · kind · criteria · source · query or command · baseline · threshold rule · cadence · failure means · action or owner.
   - No Monitoring plan → build one from diff and plan with [`monitoring-plan.md`](assets/templates/monitoring-plan.md). Get human's yes before window starts.
2. `scripts/check-plan.sh <plan>` → fix `violations[]` until exit 0.
3. Discover sources in this session. Mark each signal `available` or `manual` (see Signal map). `manual` signals reported, never silently skipped.
4. Baseline: pre-deploy values from `baseline=`, or same queries run against pre-deploy period. None → capture at tick 0, mark baseline `weak`. Write with `scripts/log-entry.sh <log> baseline`.
5. Plan ticks: `scripts/window.sh --duration <window> --cadence <cadence> --start <deploy time>`. Self-paced: schedule each wake-up with harness scheduling or loop facility. Never busy-poll.
6. Each tick: collect every due signal into CURRENT JSON → `scripts/compare.sh baseline.json current.json rules.json` → `scripts/log-entry.sh <log> tick` with compare output. Tick ≤ 8 lines in chat; quiet tick = one line.
7. Stop at window end, on `degraded`, or when human says stop. Write `scripts/log-entry.sh <log> final`.
8. Final report ≤ 10 lines: verdict · window · signals table (ok/warn/fail/unknown) · evidence links · recommended action.

## Signal map

| Kind | Checks | Typical source |
|---|---|---|
| works | Each acceptance criterion has observable signal | Synthetic probe, API call, UI trace |
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

`compare.sh` reads RULES as JSON array built from plan's threshold column: `{"name","kind","limit"|"value","warn","allow_noise_abs"}`. Kinds: `max_ratio`, `max_abs`, `min_abs`, `equals`, `forbid_new_keys`. `scripts/compare.sh -h` lists semantics.

## Monitoring log

Dated doc ([docs-current-or-dated](../../rules/docs-current-or-dated.md)): `docs/monitor/YYYY-MM-DD-<slug>.md` or repo convention.

- `log-entry.sh` creates it with `Date:` header, appends entries during run, refuses writes after `## Final`.
- Commit only after final entry. Correction = separate dated log linking back.

## Scripts

| Script | Use | Exit |
|---|---|---|
| `scripts/window.sh --duration 2h --cadence 10m [--start ISO]` | Tick schedule JSON, capped at 288 ticks | 2 usage |
| `scripts/compare.sh BASELINE CURRENT RULES` | Verdict and per-signal status | 0 healthy, 1 degraded, 3 unknown, 2 usage |
| `scripts/log-entry.sh LOG tick\|baseline\|final` | Append entry from stdin JSON | 3 log frozen, 2 usage |
| `scripts/check-plan.sh PLAN.md` | Validate Monitoring plan | 1 violations, 3 no file |

All print JSON on stdout and take `-h`.

## Never

- Act on a finding. Recommend, then ask.
- Treat missing value, failed query, or unreachable source as healthy.
- Read prod secret or personal data into log. Record counts, rates, signature names.
- Extend window or cadence without human saying so.
