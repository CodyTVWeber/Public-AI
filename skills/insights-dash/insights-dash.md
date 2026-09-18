Update a growth tracking dashboard at a user-defined path.

## Step 0 — Locate rules file

Look for `growth-rules.md` in the same directory as `report.html`. The rules file defines what to measure, how to score it, and where data lives.

- If found: read it and follow its `## Focus Areas` and `## Data Sources` sections exactly.
- If not found: create it using the **bootstrap flow** below, then proceed.

### Bootstrap flow (first run only)
Ask the user:
1. What is the directory path where the dashboard lives (or should be created)?
2. What are 2–4 growth areas they want to track? For each, ask:
   - What does success look like? (the target state)
   - How would you measure progress? (what signal, command, or data source shows it?)
   - How often does it change? (daily / weekly / per-period)
3. What is the period cadence for history cards? (weekly, sprint, monthly, etc.)

Generate `growth-rules.md` from their answers using the template at the bottom of this file.
Generate a starter `report.html` if none exists — use `templates/report.html` in this skill's directory as the structural and visual base.

## Step 1 — Gather data

For each focus area defined in `growth-rules.md`, run the commands listed under its `source:` field. Run all sources in parallel where possible.

Also collect period stats (sessions, messages, commits or equivalent) using the commands in `## Data Sources`.

## Step 2 — Score each focus area

Apply the formula in each focus area's `score_formula:` field. Clamp results to 0–100.

**Overall** = average of all focus area scores.

## Step 3 — Update report.html

1. Read existing `report.html` to find the current period in Period History.
2. If the new data covers a different date range, add a new period card using the stats from Step 1.
3. Update focus area numbers, progress bar widths, and percentages.
4. Recalculate overall % and its progress bar.
5. Update the fun quote if the data yields a better one.

## Step 4 — Update growth-rules.md

Append to the `## Period History Notes` section: the period date range, key metric values, and any scoring corrections or new signals discovered this run.

## Step 5 — Commit (private repo)

```
git -C <dashboard-dir> add .
git commit -m "chore: update growth track [date range]"
```

## Step 6 — Sync to public repo (if configured)

Check `growth-rules.md` for a `public_repo:` field. If present:

### 6a — Sensitivity scan
Before writing anything, load the blocked patterns from `~/.claude/rules/public-repo-sensitivity.md` and scan all content destined for the public repo. Flag any match and stop — do not write until all matches are resolved.

If any match: report what matched, stop, ask user how to handle it.

### 6b — Apply aliases and write
1. Read the alias mapping from `## Public Aliases` in the **private** `growth-rules.md`
2. Apply aliases to all content (replace private names with generic labels)
3. Write sanitized `report.html` and `growth-rules.md` to `<public_repo>/growth/`
4. Re-run the sensitivity scan on the written files to confirm clean

### 6c — Show diff, wait for approval
Run `git -C <public_repo> diff` (staged and unstaged) and show the full output.
**Do NOT commit** — wait for explicit user approval before running any `git commit` in the public repo.

Output one line: private commit hash + "public repo staged, awaiting your approval".

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

Commands to gather period-level stats (sessions, messages, events, commits, etc.).
These populate the Period History cards and provide denominators for focus area formulas.

| Stat | Command | Notes |
|---|---|---|
| <stat name> | `<command>` | <what it measures> |

## Scoring Notes

Add calibration notes here as you run the dashboard over time:
- Which signals turned out to be misleading and why
- Corrections to formulas after observing real data
- Signals that were added or removed

## Period History Notes

Append one line per run:
- <date range>: <key numbers> — <one observation>
````
