# monitor

AI-agnostic skill: after a change is deployed to PROD, monitor it for a set window and report whether it works, shows no related error regressions, and leaves the data and every other checkable system correct.

Follows [watch](../watch/watch.md): watch ends when the change is merged and deployed to PROD; monitor takes over from there. Strictly read-only: it reports a verdict and asks before any action.

## Install

Symlink or copy this directory to the agent's skills folder (`SKILL.md` points to `monitor.md`).

## Invoke

- `/monitor window=2h cadence=10m plan=docs/plans/2026/03/2026-03-04-gallery.md`
- "Monitor the release for an hour"
- Phase G of `plan-implement-review-watch`: alias `apirwm` (align through monitor) or `m` (monitor alone); `window=` and `cadence=` pass through

## What it checks

| Question | Signals |
|---|---|
| Does the change work | Acceptance criteria as observable signals, synthetic probes |
| Any related errors | Error rate vs baseline, first-seen error signatures |
| Is the data right | Read-only counts, null and duplicate rates, invariants, freshness, orphans |
| Anything else | Health endpoints, latency, queues and jobs, firing alerts, feature flags, downstream consumers, business metrics |

## Pieces

| Path | Role |
|---|---|
| `monitor.md` | Skill: args, hard rules, playbook, verdicts |
| `assets/templates/monitoring-plan.md` | Signals table plus window, baseline, owner and out-of-scope sections |
| `assets/templates/monitoring-log.md` | Header of the dated log |
| `scripts/window.sh` | Tick schedule |
| `scripts/compare.sh` | Baseline vs current against rules |
| `scripts/log-entry.sh` | Append to the dated log; freezes at the final entry |
| `scripts/check-plan.sh` | Validate the Monitoring plan |

Tests: `scripts/tests/*.test.sh`, run by the repo-root `scripts/tests/run-all.sh`.
