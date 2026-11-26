### Approval gate

**Never auto-commit. Never auto-push.** Each needs explicit approval. Approving a commit ≠ approving a push.

1. Show `git status` and `git diff --staged`; wait for approval before `git commit`.
2. Ask again before `git push`.

`scripts/guard/git-approval-guard.sh` asks before every commit and push; denies `--no-verify`, `core.hooksPath` overrides, `CLEAN_CODE_SKIP`, `SKIP`, `HUSKY=0`. It backs the gate, does not replace it. Omit this block in unattended pipelines.
