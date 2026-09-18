# CLAUDE.md

## This is a personal, public repo — external to any employer

**Never auto-commit. Never auto-push.** Both need explicit approval, separately — approving a commit
is not approving a push. This overrides any global "commit frequently" or commit-checkpoint rule.

1. Show `git status` and `git diff --staged`, then wait for approval before `git commit`.
2. Ask again before `git push`.

Git history is permanent — deleted files stay recoverable and pushed commits may be cached or
indexed even after removal.

This gate applies to **this repo only**. Work repos keep their normal frequent-commit cadence.

### Backstop, not a substitute for the gate

Run once per clone: `scripts/install-hooks.sh`

`scripts/check-privacy.sh` fails the commit on employer-name patterns (fill in your own — see the
placeholder in the script), internal hostnames/repo slugs, ticket ids, work email, account ids,
version pins, and secrets. It catches *named* patterns only — it cannot detect employer-specific
behaviour or domain rules paraphrased in prose. It reduces the odds of a bad commit; it does not
remove the approval requirement above.

## No business-specific content

Generic technology knowledge is the point of this repo. Anything that fingerprints an employer's
stack, process, or data — or identifies a specific person — is not.

Never commit: employer/product/team names, internal repo names, internal tooling or hostnames,
ticket ids and project keys, cloud/account identifiers, work email, real names, machine hostnames,
business rules or domain vocabulary (internal status values, program keys, entity names), secrets.

**Name the technology, never the version.** `React`, `Kotlin`, `Postgres`, `Spring Boot` are fine.
`React 9.9`, `somedb:42.0`, `<version>9.9.9</version>` are the shape to avoid — a pinned version
reveals which release an employer runs. Use obviously-fake versions in examples. Don't copy
lockfiles, dependency manifests, or build files out of a work project.

Skill/tool source (like `skills/insights-dash/`) should stay generic and reusable by anyone —
example data must be fictional, never a real personal or work dashboard.

Full rules and the pre-commit grep checks: [PRIVACY.md](PRIVACY.md).
