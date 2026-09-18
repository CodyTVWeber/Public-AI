# insights-dash

A Claude Code skill that maintains a personal growth tracking dashboard — an HTML report scored from shell commands, git history, or any measurable signal you define.

## What it does

- Reads a `growth-rules.md` file you own (not committed to this repo) to know what to measure and how to score it
- Gathers data by running the shell commands you specify
- Updates a `report.html` with progress bars, period history cards, and an overall score
- Commits the update automatically

## Setup

**1. Install the skill**

```bash
cp insights-dash.md ~/.claude/commands/insights-dash.md
```

**2. Create your dashboard directory**

Pick any local directory — this is where your `growth-rules.md` and `report.html` will live. It can be a private git repo, a subdirectory of an existing repo, or anywhere on your machine.

```bash
mkdir ~/my-growth-dash
```

**3. First run**

```
/insights-dash
```

Claude will ask you a few questions and generate `growth-rules.md` and a starter `report.html` in your chosen directory.

## How it works

The skill is driven entirely by `growth-rules.md` — a Markdown file in your dashboard directory. That file defines:

- **Focus areas** — what you're tracking, with a target, a shell command or file path to pull data from, and a scoring formula
- **Data sources** — period-level stats (sessions, commits, messages, etc.)
- **Scoring notes** — calibration observations you add over time
- **Period history notes** — one-line log appended each run

Because `growth-rules.md` is yours and not part of this repo, the skill stays generic while your tracking stays personal.

## Subsequent runs

```
/insights-dash
```

Claude reads your existing `growth-rules.md`, gathers fresh data, and updates `report.html`. A new period card is added if the date range has changed.

## Customization

Edit `growth-rules.md` directly to:
- Add or remove focus areas
- Tune scoring formulas after observing real data
- Change the period cadence
- Add notes about what's working or misleading

## Templates

[`templates/`](templates/) — the HTML scaffold the skill uses when bootstrapping a new dashboard. Claude fills in your focus areas, scores, and period history on first run. All focus cards and list items are fully linked to their detail pages.

| File | Purpose |
|---|---|
| `report.html` | Main dashboard scaffold |
| `detail-commit-cadence.html` | Why commits matter, fix steps, copyable prompts |
| `detail-test-first.html` | TDD habit building, pattern examples, copyable prompts |
| `detail-tooling.html` | Tool adoption framework, scoring approach, getting-started steps |

## Example

[`example/`](example/) is a fictional dashboard — a made-up engineer tracking three generic habits: shipping cadence, test-first discipline, and tool adoption. Open `report.html` in a browser; all focus cards and list items link through to their detail pages.

| File | What it shows |
|---|---|
| `report.html` | Main dashboard — overall score, focus cards, period history |
| `slideshow.html` | Slide-deck walkthrough of the dashboard's anatomy |
| `detail-commit-cadence.html` | Commit cadence deep-dive — why it matters, how to fix it, copyable prompts |
| `detail-test-first.html` | Test-first habit building, pattern examples, copyable prompts |
| `detail-tooling.html` | Tool adoption framework, scoring approach, getting-started steps |

No real data — every number in `example/` is invented to demonstrate the shape of a filled-out dashboard.
