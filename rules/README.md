# Rules

Canonical, repo-independent rules. Copy into any project's `.claude/rules/`, or bootstrap a whole repo with `skills/setup-repo/scripts/bootstrap.sh <repo>` (`detect-repo.sh` first).

| Rule | One line | Enforced by |
| --- | --- | --- |
| [ban-comments.md](ban-comments.md) | No comments; rename or extract. Machine-read lines only. | `code-quality-check.sh` (PostToolUse, Stop, pre-commit), `check-clean-code.sh`, `scripts/lint/lint-clean-code.sh` |
| [docs-current-or-dated.md](docs-current-or-dated.md) | Docs are current state, or a dated immutable snapshot. | `scripts/lint/lint-docs.sh` |
| [clean-code.md](clean-code.md) | Portable floor: size, nesting, params, naming. | `code-quality-check.sh` (PostToolUse, Stop, pre-commit), linters in `skills/setup-repo/assets/lint/` |
| [agent-neutral-names.md](agent-neutral-names.md) | Name generic assets for the job, not a vendor. | review |
| [small-mrs.md](small-mrs.md) | One concern per MR; stack safest first. | `check-mr-size.sh`, `post-git-check.sh` (size note after a commit) |
| [research-latest-main.md](research-latest-main.md) | Research from the fetched default branch. | `scripts/guard/research-ref.sh` |
| [glossary-overloaded-terms.md](glossary-overloaded-terms.md) | One glossary entry per term with two meanings; list misleading code names. | review, plan check |
| [delegate-work.md](delegate-work.md) | Lead decides and does tiny writes; a reused cheaper worker does volume. | review |

`skills/setup-repo/assets/rules/` mirrors this directory for installation. `scripts/lint/check-copies.sh` fails on drift (pairs listed in `scripts/lint/copies.list`); `--fix` copies here → there.
- [ai-files-telegraphic](ai-files-telegraphic.md) — AI-facing files: telegraphic, dense, human-scannable
