# Privacy & Sanitization Rules

This is a **personal** repository and it is **public**. It is external to any employer. All content
must be free of personal or employer-identifying information before committing.

Nothing business-specific goes in here. Generic technology knowledge is the point of this repo;
anything that could fingerprint an employer's stack, process, or data — or identify you or anyone
else personally — is not.

## Agent rules — ship clean content

Agents commit, push, and merge per commit-and-ship (low-risk repo). Every commit and push is an exposure point, so the privacy checks below run on both; review staged content for anything they can't catch before shipping.

Git history is permanent: deleted files stay recoverable, and pushed commits may be cached or
indexed even if force-removed later. This overrides any global "commit frequently" or
commit-checkpoint instruction — and applies to **this repo only**.

### Automated backstop

The approval gate above is the rule. This hook only lowers the odds of a mistake reaching it:

```sh
scripts/install-hooks.sh    # once per clone
```

`scripts/install-hooks.sh` installs three hooks, all calling `scripts/check-privacy.sh`:

| Hook | Scans |
|---|---|
| `pre-commit` | staged additions (content), staged file names and staged binaries |
| `commit-msg` | the commit message (`#` comment lines ignored; `Signed-off-by`/`Co-Authored-By` lines skip the email check only) |
| `pre-push` | added lines, file names, commit messages and binaries of the commits being pushed (`--range auto`: `@{u}..HEAD`, else `origin/<default>..HEAD`, else the last commit), then the branch size check |

By hand: `scripts/check-privacy.sh [--content | --paths | --message FILE | --range REV_RANGE] [--strict]`. It blocks on: employer
name, internal hostname, ticket id (`[A-Z]{2,}-[0-9]+`, case-sensitive; `SHA-256`, `UTF-8` and similar
standards tokens pass), account id, home path, email, private IP, git remote, cloud ARN, phone
number, PO box, street address, city/state/ZIP, version pins (semver, docker tag, `name:N.N` tag-style
pin anywhere, build-file version elements, `@vN` action pins, `name-N.N` model-version tokens), secrets, and binaries.

- Local patterns: the untracked file `<git-dir>/info/privacy-patterns` (`git rev-parse --git-path info/privacy-patterns`)
  holds one extended regex per line for the employer name, internal hostnames and repo slugs; blank and
  `#` lines are ignored. The file stays out of every commit. Without it the script warns on stderr every
  run and only the generic checks apply. `--strict` or `PRIVACY_REQUIRE_PATTERNS=1` turns a missing file
  into a block; `scripts/install-hooks.sh` writes that env into the hooks of a clone whose file exists.
  `PRIVACY_EMPLOYER_PATTERN` (or `EMPLOYER_PATTERN` in the script) adds one more employer regex.
- Binaries (`git diff --numstat` reports `-`, or extension png jpg jpeg gif webp pdf zip gz ico mov mp4
  docx xlsx) block until a human reviews them and lists the path in `.privacyallow-binaries`, one path per line.
- Version-pin exception: `actions/checkout@v4` in `skills/setup-repo/assets/ci/github-ai-guardrails.yml`
  (allowed in `.privacyallow`); the CI template needs a real pin.
- `core.hooksPath` redirects where git looks for hooks; `scripts/install-hooks.sh` warns when it is set.
- Existing foreign hooks are saved once as `<name>.bak` and still run after the check; install never
  overwrites a second one.
- False positive? Add a narrow regex to `.privacyallow` — each entry is a hole in the gate, keep it short.
- `git commit --no-verify` bypasses the commit hooks; `git push --no-verify` bypasses `pre-push`. Use deliberately, not to get unstuck.
- Agents are also gated by a Claude Code hook (`scripts/guard/git-approval-guard.sh`) that asks before
  any commit or push and denies `--no-verify`. It backs up the gate; it does not replace it.

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
| Personal identity | Real name (in file content), work email, phone numbers, street addresses, PO boxes, machine hostnames |
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
