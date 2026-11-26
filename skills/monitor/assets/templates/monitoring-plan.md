# Monitoring plan: template gallery

Fill every section. `scripts/check-plan.sh <this-file>` exit 0 before window starts. Rows are fictional; replace.

## Acceptance criteria

- AC1: Visitor sees template gallery from start page.
- AC2: Choosing a template creates a document from it.

Touches data: yes

## Signals

| Signal | Kind | Criteria | Source | Query or command | Baseline | Threshold rule | Cadence | Failure means | Action or owner |
|---|---|---|---|---|---|---|---|---|---|
| gallery_probe_status | works | AC1 | synthetic probe | GET gallery page, record status | 200 | equals 200 | 5m | Page not served | On-call decides: flag off or rollback |
| gallery_5xx_rate | error | AC1, AC2 | APM | 5xx responses per minute on gallery endpoint | mean of hour before deploy | max_ratio 1.5, allow_noise_abs 2 | 10m | Requests fail for visitors | On-call decides: rollback or hotfix |
| error_signatures | error | AC1, AC2 | error tracker | distinct error signatures in gallery service | set seen in 24 hours before deploy | forbid_new_keys | 10m | Failure mode the change introduced | Author triages; hotfix or keep watching |
| gallery_item_rows | data | AC2 | read-only SQL | `SELECT count(*) FROM gallery_items` | count before deploy | min_abs 1 | 10m | Catalog empty or truncated | Data owner inspects; rollback if confirmed |
| gallery_item_null_title_rate | data | AC2 | read-only SQL | share of `gallery_items` rows with null title | rate before deploy | max_abs 0.01 | 30m | Bad rows written | Data owner inspects; flag off |
| gallery_p95_ms | latency | AC1 | APM | p95 latency of gallery endpoint | mean of hour before deploy | max_ratio 1.3 | 10m | Page slower for visitors | Author profiles; keep watching or rollback |
| render_queue_backlog | queue | AC2 | queue console | messages waiting in render queue | depth before deploy | max_abs 100 | 10m | Jobs not draining | On-call scales or rolls back |

Kinds: works, error, data, health, latency, queue, alert, flag, downstream, kpi, probe. Threshold rules start with `max_ratio`, `max_abs`, `min_abs`, `equals`, `forbid_new_keys`. `allow_noise_abs N` ignores deltas below N.

## Window and cadence

- Window: 1h, starting when deploy reaches prod
- Cadence: 10m (signal cadence = multiple of this)
- Stop early on degraded verdict

## Baseline

- Captured before deploy, from same sources, same query text
- No pre-deploy values: capture at tick 0, mark baseline weak

## Rollback or escalation owner

- Decides: on-call engineer for gallery service
- Contact path: team on-call rotation
- Monitor reports evidence and recommendation; never acts

## Out-of-scope signals

- Mobile app store ratings: no feed during window
- Weekly retention: needs more than one day of data
