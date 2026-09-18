# Privacy & Sanitization Rules

This is a **personal** repository and it is **public**. It is external to any employer. All content
must be free of personal or employer-identifying information before committing.

Nothing business-specific goes in here. Generic technology knowledge is the point of this repo;
anything that could fingerprint an employer's stack, process, or data — or identify you or anyone
else personally — is not.

## Agent rules — commit and push are both gated

**Never auto-commit and never auto-push to this repo.** They are two separate exposure points, so
approval for one is not approval for the other.

1. Show `git status` and `git diff` (or `git diff --staged`) and wait for explicit approval before `git commit`.
2. Ask **again** before `git push`.

Git history is permanent: deleted files stay recoverable, and pushed commits may be cached or
indexed even if force-removed later. This overrides any global "commit frequently" or
commit-checkpoint instruction — and applies to **this repo only**.

### Automated backstop

The approval gate above is the rule. This hook only lowers the odds of a mistake reaching it:

```sh
scripts/install-hooks.sh    # once per clone
```

`scripts/check-privacy.sh` scans staged additions and fails the commit on anything in the table
below. It runs automatically as `pre-commit`, and can be run by hand against the staging area.

- The employer-name check ships with a placeholder pattern (`YOUR_EMPLOYER_HERE`) — edit
  `EMPLOYER_PATTERN` in the script to match your own employer before relying on it.
- False positive? Add a narrow regex to `.privacyallow` — each entry is a hole in the gate, keep it short.
- `git commit --no-verify` bypasses it. Use deliberately, not to get unstuck.

**Limit to know:** the hook matches *named* patterns. It cannot detect employer-specific behaviour,
workflows, or domain rules paraphrased in prose. That remains a writing discipline, not a check.

## What must NOT be committed

| Category | Examples |
|---|---|
| Employer names & trademarks | Company name, product names, team names |
| Internal repo names | Any private/work repo slug |
| Work-specific tooling | Internal CLI tools, proprietary scripts, internal hostnames |
| Issue tracker references | Internal ticket IDs, internal project keys |
| Cloud/infra identifiers | AWS account IDs, internal domain names, VPN configs |
| Personal identity | Real name (in file content), work email, machine hostnames |
| API keys & secrets | Tokens, passwords, credentials of any kind |
| **Specific dependency & runtime versions** | Pinned versions of anything — a version reveals which release an employer runs, and pins date the stack. Name the technology, never the version. |
| Business rules & domain vocabulary | Internal status values, program/product keys, entity names, workflow stages |
| Real personal data | Real growth-tracking data, real dashboards, real filenames tied to a specific person's setup — skill/tool source stays generic; examples must be fictional |

### Versions: name the technology, not the release

| Not committable | Commit instead |
|---|---|
| `SomeFramework 9.9.9`, `SomeDb 42.0`, `SomeLang 7.1` | `SomeFramework`, `SomeDb`, `SomeLang` |
| `image: somedb:42.0`, `<version>9.9.9</version>` | omit the tag/version, or use `<version>` |
| "upgraded from X 2.1 to 2.4" | "upgraded a major version" |

Use obviously-fake versions in examples. Real ones — even as illustrations — disclose the stack.

General concepts, patterns, and language features are safe. Version numbers, lockfiles, dependency
manifests, and build files copied from a work project are not.

## Sanitization conventions

| Sensitive value | Replacement |
|---|---|
| Employer name | omit or use `<employer>` |
| Internal repo names | omit or use `<work-repo>` |
| Internal CLI (employer-specific tool) | use the generic equivalent (e.g. `git`, `gh`) or `<vcs-cli>` |
| IDE name (employer-licensed) | use `IDE` (generic) |
| Machine hostname | omit entirely |
| Work email | omit — use personal email for git commits |
| Real name | omit or use a placeholder persona |

## What IS safe to commit

- Generic terminal tool names (`git`, `nvim`, `yazi`, `tmux`, `ghostty`, `claude`)
- Unversioned technology names — languages, frameworks, databases, patterns
- Aggregate stats with no identifying context — but only if fictional/example, not your real numbers
- Goals, scoring formulas, and growth-rules *shapes* that describe habits generically
- HTML dashboards built from fictional example data

## Enforcement

Applies to **every** commit in this repo. Review the staged diff before asking for approval:

```sh
git diff --staged

# Employer / tooling leakage (fill in your own employer's name/domain):
grep -rEi "YOUR_EMPLOYER_HERE" .

# Version pins — semver, docker tags, maven/npm version elements:
grep -rEn "[0-9]+\.[0-9]+\.[0-9]+|:[0-9]+\.[0-9]+|<version>|\"version\":" . \
  --exclude-dir=.git --exclude-dir=node_modules

# Ticket ids / internal project keys:
grep -rEn "[A-Z]{2,}-[0-9]+" . --exclude-dir=.git
```

Also ensure your git author email is set to your personal email:

```sh
git config user.email   # should NOT be a work address
```
