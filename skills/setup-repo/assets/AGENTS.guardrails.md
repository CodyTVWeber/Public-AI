<!-- ai-guardrails:begin -->
## AI guardrails

Installed by `setup-repo` from a Public-AI clone. Rules live in `.claude/rules/`; the scripts that enforce them live in `scripts/clean-code/`.

### Installed

{{INSTALLED}}

### Thresholds

| Check | Warn | Error |
|---|---|---|
| File size (only when a change grows the file) | 200 lines | 400 lines |
| Function length | 40 lines of logic | 80 lines |
| Parameters | 3 | 4 |
| Nesting depth | 3 | 4 |
| Branch size | 400 changed lines | 800 changed lines |
| Commit subject | | 72 characters |

Findings count only on lines the change touches. Tune with the `CC_*`, `MR_SIZE_*` and `FILE_*` env vars; `scripts/clean-code/code-quality-check.sh -h` lists them. A blocked commit or push means fix or split, not bypass.

### Guard limits

- The approval guard reads the command line only. A script, Makefile target, or package script that runs `git commit` or `git push` inside (`./push.sh`, `make push`, `npm run release`) is not analysed and passes unless the command line names the action.
- Text built at runtime (base64, string concatenation, a downloaded script) passes the same way.
- Gated as a commit: `merge`, `cherry-pick`, `revert`, `am`, `rebase -x`, `commit-tree`, `update-ref`, `submodule foreach`. `send-pack` is gated as a push. `gh pr merge|create`, `glab mr merge|create` and `gh|glab api` writes ask.
- Text piped into a shell, inline code in `python`, `perl`, `ruby`, `node`, `awk`, an unknown git subcommand (a possible alias), and a command word built at runtime ask when the text names a commit or push.
- Any `core.hooksPath` write (`git -c`, `git config`, `GIT_CONFIG_*`, `--config-env`) and `--no-verify` on a gated command are denied.

### Skills

{{SKILLS}}

### Stack notes

{{STACK_NOTES}}

### Pipeline

{{PIPELINE}}

{{APPROVAL}}### Re-run

{{RERUN}}
<!-- ai-guardrails:end -->
