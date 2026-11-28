<!-- ai-guardrails:begin -->
## AI guardrails

Installed by `setup-repo` from a Public-AI clone. Rules: `.claude/rules/`. Enforcing scripts: `scripts/clean-code/`.

### Installed

{{INSTALLED}}

### While editing

Write to `.claude/rules/` on every touched line. The checks above fail the edit, commit, push, or pipeline when a line misses. Also: no added comments, TODO, or empty catch; no parameter mutation; docs are current state or a dated snapshot. Thresholds below. Fix the finding. Never skip the check.

### Thresholds

| Check | Warn | Error |
|---|---|---|
| File size (only when a change grows the file) | 200 lines | 400 lines |
| Function length (`CC_FUNC_SIZE`, default `b`) | 20 lines of logic | 40 lines |
| Parameters | 3 | 4 |
| Nesting depth | 3 | 4 |
| Branch size | 400 changed lines | 800 changed lines; docs and repo-support files omitted |
| Commit subject | | 72 characters |

- Findings count only on lines the change touches
- Hard branch size omits documentation and repo-support files (AI setup, lint and guard scripts). The warning still counts them
- Function length profiles: `CC_FUNC_SIZE=a|b|c` or `.func-size` line `size: a|b|c` (`a` 40/80, `b` 20/40 default, `c` 50/100). `CC_FUNC_WARN` / `CC_FUNC_ERROR` override
- Tune: `CC_*`, `MR_SIZE_*`, `FILE_*` env vars. `scripts/clean-code/code-quality-check.sh -h` lists them
- Blocked commit or push → fix or split. Never bypass

### Guard limits

- Approval guard reads the command line only. Script, Makefile target, or package script running `git commit` or `git push` inside (`./push.sh`, `make push`, `npm run release`) is not analysed → passes unless the command line names the action
- Runtime-built text (base64, string concatenation, downloaded script) passes the same way. So do plain `rebase` and `pull`
- Gated as commit: `merge`, `cherry-pick`, `revert`, `am`, `rebase -x`, `commit-tree`, `update-ref`, `submodule foreach`. `send-pack` gated as push
- `gh pr merge|create`, `glab mr merge|create`, `gh|glab api` writes: ask
- Ask when the text names a commit or push and it is: piped into a shell, inline code in `python`, `perl`, `ruby`, `node`, `awk`, an unknown git subcommand (possible alias), or a runtime-built command word
- Any `core.hooksPath` write (`git -c`, `git config`, `GIT_CONFIG_*`, `--config-env`) and `--no-verify` on a gated command: denied

### Skills

{{SKILLS}}

### Stack notes

{{STACK_NOTES}}

### Pipeline

{{PIPELINE}}

{{APPROVAL}}### Re-run

{{RERUN}}
<!-- ai-guardrails:end -->
