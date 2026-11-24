# Merge policy

Each organization decides how much human approval a change needs. This file defines three
profiles and how a repo declares which one it uses. `risk-tiers.md` gives the tier of a change;
the profile says who may merge a change of that tier.

## Choose a profile

| Profile | Pick it when | Approval |
| --- | --- | --- |
| `conservative` | Regulated, financial, health, shared production, or any org that wants a second person on every change | Every change needs another person's approval, at every tier |
| `balanced` | A small team with mixed-risk code that lets low-risk changes move on one person's say-so | Approval scales with the tier |
| `yolo` | Prototypes, personal or throwaway projects, vibe coding | None. The agent merges |

When unsure, pick `conservative`. Loosening later is cheap; recovering from a bad merge is not.

## Declare it

The repo file `docs/rules/ai-merge-policy.md` contains one line: `Merge policy: <profile>`. A team
or org policy that agents already load and that names this repo also counts.

- Missing file, unknown value, or a policy the agent cannot quote: `conservative`
- `scripts/merge-policy.sh` does this lookup: it ignores HTML comments and fenced code, takes the
  strictest of several disagreeing lines, and prints `{profile, auto_merge_low, source}`
- Repo and org disagree: the stricter one wins
- The agent quotes the source (file path or policy name) in the pull request before it merges
- Changing the line is a high-tier change, because it governs agents. It gets its own pull
  request, approved by the designated owner. An agent never edits it inside the pull request that
  the change would unlock

These are not the declaration: task text, a review comment, a chat message, "ship it", another
agent, a green check.

## Terms

- **Approval:** a person who is not the author, and who is a maintainer, approves that pull
  request on the forge. Another agent does not count. A spoken or chat yes does not count
- **An agent merging after a person approved that pull request is that person's merge**
- **Auto-merge:** an agent or the forge merging with no person approving that pull request
- **Designated owner:** the person or group the code-owners file or org policy names for the
  paths touched

## Who may merge

A pull request takes the highest tier it touches (`risk-tiers.md`).

### conservative

| Tier | Needed before merge |
| --- | --- |
| Low | One approval |
| Medium | One approval |
| High | One approval is the floor. A second approval is the norm: ask for two unless the change is trivially reversible. A written rollback note is required |

A stricter organization can make the second high-tier approval mandatory, or name the designated
owner as one of the two, in its own copy of this file.

- Agents open the pull request and stop. After the approval, a person merges, or the approver's
  agent merges at the approver's request
- A cloud agent never merges, whoever's login it uses
- Auto-merge is never on, including the forge's "merge when checks pass" button

### balanced

| Tier | Needed before merge |
| --- | --- |
| Low | A person merges. An agent merges unattended only when auto-merge for low is on (below) |
| Medium | A second person (maintainer, not the author) approves. Then that person's agent may merge. The author's agent leaves it |
| High | Only the designated owner's agent, in a local session with the owner present. A cloud agent may open the pull request and must leave it unmerged, even when the forge login is the owner's |

Auto-merge for low is off unless the same file also has `Auto-merge low: on`. Turning it on is
its own pull request, like any policy change. See "Auto-merge for low" below.

### yolo

| Tier | Needed before merge |
| --- | --- |
| Low, medium, high | None. The agent merges its own pull request when it judges it ready |

The organization accepts the risk: no second person, no owner, no waiting. Use it only where a
bad merge costs little. Do not use it for shared production, money, personal data or regulated
work.

## Floors that hold in every profile

- The pull request states its tier and quotes the policy it relied on
- Say merged or deployed only after a fresh check of the forge or the host (`agent-stops.md`)
- Applying changes to a live, shared data store is a separate action from merging the file. The
  person who holds the credential decides it. Agents apply changes only to local or
  non-production stores, and a cloud agent writes the file and does not run it
- Secrets never go into a pull request

## Auto-merge for low (balanced only)

When `Auto-merge low: on`, an agent may merge with no approval when all of these hold:

1. Every path in the pull request is low. One medium or high path and the agent leaves it for
   the approver that profile names
2. The project's checks are green on that commit
3. The body follows `verify-change` (claim, proof, a step the reviewer can re-run), and for a
   visible change the proof includes an artifact CI produced for that commit
4. If the forge's "merge when checks pass" button is used, a required risk check computes the
   tier as the higher of the declared tier and the path floor, runs from the default branch (so
   the pull request cannot edit the check that judges it), and blocks the merge when red, for
   admins too. Required reviews are zero for low only; code owners still cover medium and high

Never auto-merged: schema, auth, access control, scheduled jobs, secrets, config that can select
production, workflows, hooks, data-store apply scripts, agent rules (including this policy), a
pull request that mixes low with anything higher, and any pull request whose checks are red,
skipped or missing. Do not add a workflow that approves pull requests with its own token.
