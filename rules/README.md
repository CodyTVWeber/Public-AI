# Rules

Canonical, repo-independent rules. Copy into any project's `.claude/rules/`, or bootstrap a whole repo with `skills/setup-repo/scripts/bootstrap.sh <repo>` (`detect-repo.sh` first).

| Rule | One line | Enforced by |
| --- | --- | --- |
| [ban-comments.md](ban-comments.md) | No comments; rename or extract. Machine-read lines only. | `code-quality-check.sh` (PostToolUse, Stop, pre-commit), `check-clean-code.sh`, `scripts/lint/lint-clean-code.sh` |
| [docs-current-or-dated.md](docs-current-or-dated.md) | Docs are current state, or a dated immutable snapshot. | `scripts/lint/lint-docs.sh` |
| [clean-code.md](clean-code.md) | Portable floor: size, order, nesting, params, naming. | `code-quality-check.sh` (PostToolUse, Stop, pre-commit), linters in `skills/setup-repo/assets/lint/` |
| [deterministic-checks.md](deterministic-checks.md) | Scripts decide mechanical checks. AI judges only the gaps. | the scripts that file names |
| [ai-thinking-dense.md](ai-thinking-dense.md) | Reasoning is telegraphic; fewest tokens that still decide. | review |
| [agent-neutral-names.md](agent-neutral-names.md) | Name generic assets for the job, not a vendor. | review |
| [agent-source.md](agent-source.md) | Edit `AGENTS.md` only. Vendor files redirect there. | review |
| [small-mrs.md](small-mrs.md) | One concern per MR; app, support, and docs sized apart; stack safest first. | `check-mr-size-app.sh`, `check-mr-size-support.sh`, `check-mr-size-docs.sh`, `post-git-check.sh` (size note after a commit) |
| [research-latest-main.md](research-latest-main.md) | Research from the fetched default branch. | `scripts/guard/research-ref.sh` |
| [glossary-overloaded-terms.md](glossary-overloaded-terms.md) | One glossary entry per term with two meanings; list misleading code names. | review, plan check |
| [scripting-languages.md](scripting-languages.md) | Scripts are Bash or JavaScript; deps pinned and locked. | `scripts/lint/check-languages.sh` (git `pre-commit`) |
| [delegate-work.md](delegate-work.md) | Lead decides and does tiny writes; a reused cheaper worker does volume. | review |
| [frustration-fix-agent.md](frustration-fix-agent.md) | Frustration or vague "work harder" → setup tweak, then cleanup rounds (extract copies, domain grouping). | agent judgment |

`skills/setup-repo/assets/rules/` mirrors this directory for installation. `scripts/lint/check-copies.sh` fails on drift (pairs listed in `scripts/lint/copies.list`); `--fix` copies here → there.
- [ai-files-telegraphic](ai-files-telegraphic.md) — AI-facing files: telegraphic, dense, human-scannable
- [commit-and-ship](commit-and-ship.md) — commit, push, MR by default; merge in low-risk repos
