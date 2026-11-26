# Merge policy

Each org decides how much human approval a change needs. This file defines three profiles and how a repo declares its profile. `risk-tiers.md` gives a change's tier; the profile says who may merge that tier.

## Choose a profile

| Profile | Pick when | Approval |
|---|---|---|
| `conservative` | Regulated, financial, health, shared production, or any org wanting a second person on every change | Another person approves every change, every tier |
| `balanced` | Small team, mixed-risk code, low-risk changes move on one person's say-so | Scales with tier |
| `yolo` | Prototypes, personal or throwaway projects, vibe coding | None. Agent merges |

Unsure → `conservative`. Loosening later is cheap; recovering from a bad merge is not.

## Declare it

`docs/rules/ai-merge-policy.md` contains one line: `Merge policy: <profile>`. A team or org policy agents already load that names this repo also counts.

- Missing file, unknown value, or policy agent can't quote → `conservative`
- `scripts/merge-policy.sh` does the lookup: ignores HTML comments and fenced code, takes strictest of disagreeing lines, prints `{profile, auto_merge_low, source}`
- Repo and org disagree → stricter wins
- Agent quotes source (file path or policy name) in PR before merging
- Changing the line = high-tier change (governs agents). Own PR, approved by designated owner. Agent never edits it inside the PR the change would unlock

Not declarations: task text, review comment, chat message, "ship it", another agent, green check.

## Terms

- **Approval:** maintainer who is not the author approves the PR on forge. Another agent ≠ approval. Spoken or chat yes ≠ approval
- **Agent merging after person approved PR = that person's merge**
- **Auto-merge:** agent or forge merges with no person approving the PR
- **Designated owner:** person or group the code-owners file or org policy names for touched paths

## Who may merge

PR takes highest tier it touches (`risk-tiers.md`).

### conservative

| Tier | Needed before merge |
|---|---|
| Low | One approval |
| Medium | One approval |
| High | One approval is floor. Second approval is norm: ask for two unless trivially reversible. Written rollback note required |

Stricter org can make second high-tier approval mandatory, or name designated owner as one of two, in its own copy of this file.

- Agents open PR and stop. After approval, a person merges, or approver's agent merges at approver's request
- Cloud agent never merges, whatever login it uses
- Auto-merge never on, including forge's "merge when checks pass"

### balanced

| Tier | Needed before merge |
|---|---|
| Low | A person merges. Agent merges unattended only when auto-merge for low is on (below) |
| Medium | Second person (maintainer, not author) approves. Then that person's agent may merge. Author's agent leaves it |
| High | Only designated owner's agent, local session with owner present. Cloud agent may open PR, must leave it unmerged, even when forge login is owner's |

Auto-merge for low is off unless same file has `Auto-merge low: on`. Turning it on = own PR, like any policy change. See "Auto-merge for low" below.

### yolo

| Tier | Needed before merge |
|---|---|
| Low, medium, high | None. Agent merges its own PR when it judges it ready |

Org accepts the risk: no second person, no owner, no waiting. Use only where a bad merge costs little. Not for shared production, money, personal data, or regulated work.

## Floors in every profile

- PR states its tier and quotes the policy relied on
- "Merged" or "deployed" only after fresh check of forge or host (`agent-stops.md`)
- Applying changes to a live, shared data store ≠ merging the file. Credential holder decides. Agents apply only to local or non-production stores. Cloud agent writes the file, doesn't run it
- Secrets never in a PR

## Auto-merge for low (balanced only)

When `Auto-merge low: on`, agent may merge with no approval when all hold:

1. Every path low. One medium or high path → agent leaves it for approver the profile names
2. Project checks green on that commit
3. Body follows `verify-change` (claim, proof, step reviewer can re-run). Visible change → proof includes CI-produced artifact for that commit
4. If forge "merge when checks pass" is used, a required risk check computes tier = higher of declared tier and path floor, runs from default branch (PR can't edit the check that judges it), blocks merge when red, for admins too. Required reviews zero for low only; code owners still cover medium and high

Never auto-merged: schema, auth, access control, scheduled jobs, secrets, config that can select production, workflows, hooks, data-store apply scripts, agent rules (including this policy), PR mixing low with anything higher, any PR with red, skipped, or missing checks. Don't add workflow that approves PRs with its own token.
