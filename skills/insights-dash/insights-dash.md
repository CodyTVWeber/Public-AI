Update growth tracking dashboard at user-defined path.

## Step 0: Locate rules file

Find `growth-rules.md` in same dir as `report.html`. It defines what to measure, how to score, where data lives.

- Found → follow its `## Focus Areas` and `## Data Sources` exactly.
- Not found → bootstrap flow below, then proceed.

### Bootstrap flow (first run only)

Ask user:

1. Dashboard dir path (or where to create it).
2. 2–4 growth areas. Per area:
   - Success = target state?
   - Measure how? (signal, command, or data source)
   - Change frequency? (daily / weekly / per-period)
3. Period cadence for history cards? (weekly, sprint, monthly, etc.)
4. Run automatically going forward? Yes → Step 7.

Generate `growth-rules.md` from answers using template at bottom.
Generate starter `report.html` if none: base on `templates/report.html` in skill dir.

## Step 1: Gather data

- Per focus area: run its `source:` commands. Run all sources in parallel where possible.
- Collect period stats (sessions, messages, commits or equivalent) via `## Data Sources`.

## Step 2: Score

- Apply each area's `score_formula:`. Clamp 0–100.
- **Overall** = average of area scores.

## Step 3: Update report.html

1. Read `report.html`; find current period in Period History.
2. Different date range → add period card from Step 1 stats.
3. Update focus-area numbers, progress bar widths, percentages.
4. Recalculate overall % and its progress bar.
5. Update fun quote if data yields a better one.

## Step 4: Update growth-rules.md

Append to `## Period History Notes`: date range, key metric values, scoring corrections or added signals found this run.

## Step 5: Commit (private repo)

```
git -C <dashboard-dir> add .
git commit -m "chore: update growth track [date range]"
```

## Step 6: Sync to public repo (if configured)

Check `growth-rules.md` for `public_repo:`. If present:

### 6a: Sensitivity scan

- Load blocked patterns from `~/.claude/rules/public-repo-sensitivity.md`. Scan all content destined for public repo.
- Match → report what matched, stop, ask user how to handle. Write nothing until resolved.

### 6b: Apply aliases and write

1. Read alias mapping from `## Public Aliases` in **private** `growth-rules.md`.
2. Apply aliases to all content (private names → generic labels).
3. Write sanitized `report.html` and `growth-rules.md` to `<public_repo>/growth/`.
4. Re-run sensitivity scan on written files.

### 6c: Show diff, wait for approval

- Run `git -C <public_repo> diff` (staged + unstaged). Show full output.
- **Do NOT commit.** Wait for explicit user approval before any `git commit` in public repo.
- Output one line: private commit hash + "public repo staged, awaiting your approval".

## Step 7: Automate with /loop

If user wants own cadence (asked at bootstrap, or asks "how do I automate this"), suggest:

```
/loop once a week, run '/insights' and then run '/insights-dash', commit and push.
```

Substitute cadence (daily, weekly, per-sprint). Tell user:

- Recurring `/loop` jobs auto-expire after 7 days. Weekly job fires once, then needs rescheduling.
- Options: re-run `/loop` after each fire, or ask for `durable: true` (survives restart; 7-day expiry still applies).

---

## growth-rules.md template

````markdown
# Growth Rules

Goal: <one sentence describing what you are trying to get better at>
Last updated: <date>

## Focus Areas

Each focus area becomes one card on the dashboard.

<!--
Schema per area:
- name: display label
- target: what 100% looks like
- source: shell command(s) or data location to pull the raw number
- score_formula: how to turn the raw number into 0–100 (plain English or math)
- notes: anything that affects how to interpret the signal
-->

### <Area 1 name>
- target: <what done looks like>
- source: `<command or file to read>`
- score_formula: <formula or rule, e.g. "min(value / target_value, 1) * 100">
- notes: <gotchas, caveats, alternative signals>

### <Area 2 name>
- target: <what done looks like>
- source: `<command or file to read>`
- score_formula: <formula or rule>
- notes: <gotchas>

### <Area 3 name>
- target: <what done looks like>
- source: `<command or file to read>`
- score_formula: <formula or rule>
- notes: <gotchas>

## Data Sources

Commands for period-level stats (sessions, messages, events, commits, etc.).
Populate Period History cards and provide denominators for focus-area formulas.

| Stat | Command | Notes |
|---|---|---|
| <stat name> | `<command>` | <what it measures> |

## Scoring Notes

Calibration notes, added over time:
- Misleading signals and why
- Formula corrections after observing real data
- Signals added or removed

## Period History Notes

Append one line per run:
- <date range>: <key numbers> — <one observation>
````
