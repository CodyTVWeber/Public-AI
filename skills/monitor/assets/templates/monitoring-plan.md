# Monitoring plan: template gallery

Fill every section. `scripts/check-plan.sh <this-file>` must exit 0 before the window starts. The rows below are fictional examples; replace them.

## Acceptance criteria

- AC1: A visitor sees the template gallery from the start page.
- AC2: Choosing a template creates a document from it.

Touches data: yes

## Signals

| Signal | Kind | Criteria | Source | Query or command | Baseline | Threshold rule | Cadence | Failure means | Action or owner |
|---|---|---|---|---|---|---|---|---|---|
| gallery_probe_status | works | AC1 | synthetic probe | GET the gallery page, record the status | 200 | equals 200 | 5m | The page is not served | On-call decides: flag off or rollback |
| gallery_5xx_rate | error | AC1, AC2 | APM | 5xx responses per minute on the gallery endpoint | mean of the hour before deploy | max_ratio 1.5, allow_noise_abs 2 | 10m | Requests fail for visitors | On-call decides: rollback or hotfix |
| error_signatures | error | AC1, AC2 | error tracker | distinct error signatures in the gallery service | set seen in the 24 hours before deploy | forbid_new_keys | 10m | A failure mode the change introduced | Author triages; hotfix or keep watching |
| gallery_item_rows | data | AC2 | read-only SQL | `SELECT count(*) FROM gallery_items` | count before deploy | min_abs 1 | 10m | The catalog is empty or was truncated | Data owner inspects; rollback if confirmed |
| gallery_item_null_title_rate | data | AC2 | read-only SQL | share of `gallery_items` rows with a null title | rate before deploy | max_abs 0.01 | 30m | Bad rows are being written | Data owner inspects; flag off |
| gallery_p95_ms | latency | AC1 | APM | p95 latency of the gallery endpoint | mean of the hour before deploy | max_ratio 1.3 | 10m | The page is slower for visitors | Author profiles; keep watching or rollback |
| render_queue_backlog | queue | AC2 | queue console | messages waiting in the render queue | depth before deploy | max_abs 100 | 10m | Jobs are not draining | On-call scales or rolls back |

Kinds: works, error, data, health, latency, queue, alert, flag, downstream, kpi, probe. Threshold rules start with one of `max_ratio`, `max_abs`, `min_abs`, `equals`, `forbid_new_keys`; `allow_noise_abs N` ignores deltas below N.

## Window and cadence

- Window: 1h, starting when the deploy reaches prod
- Cadence: 10m (a signal's own cadence is a multiple of this)
- Stop early on a degraded verdict

## Baseline

- Captured: before the deploy from the same sources, on the same query text
- No pre-deploy values: capture at tick 0 and mark the baseline weak

## Rollback or escalation owner

- Decides: the on-call engineer for the gallery service
- Contact path: the team's on-call rotation
- The monitor reports evidence and a recommendation; it never acts

## Out-of-scope signals

- Mobile app store ratings: no feed during the window
- Weekly retention: needs more than one day of data
