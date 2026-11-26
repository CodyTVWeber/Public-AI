## Clean code and small MRs

- Rules: [.claude/rules/clean-code.md](.claude/rules/clean-code.md), [.claude/rules/ban-comments.md](.claude/rules/ban-comments.md), [.claude/rules/small-mrs.md](.claude/rules/small-mrs.md), [.claude/rules/docs-current-or-dated.md](.claude/rules/docs-current-or-dated.md). Follow all four on every change. No comments; docs = current state or dated snapshot
- Self-check touched files before each commit. One concern per MR; ideally ≤200, never >400 changed lines without reason
- Stacked MRs: safest first, riskiest last (cutovers, destructive steps, behavior changes on top) so a revert isolates the risk
- Enforcement: git pre-commit and pre-push hooks, Claude Code hooks. All backed by `scripts/clean-code/`. Blocked commit or push → fix or split, never bypass
- Size check: `scripts/clean-code/check-mr-size.sh`
