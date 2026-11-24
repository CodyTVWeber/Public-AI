## Clean code and small MRs

- Rules: [.claude/rules/clean-code.md](.claude/rules/clean-code.md), [.claude/rules/ban-comments.md](.claude/rules/ban-comments.md), [.claude/rules/small-mrs.md](.claude/rules/small-mrs.md), [.claude/rules/docs-current-or-dated.md](.claude/rules/docs-current-or-dated.md). Follow all four on every change. No comments; docs are current state or a dated snapshot.
- Self-check touched files before each commit; keep MRs to one concern, ideally ≤ 200 and never over 400 changed lines without a reason.
- Stacked MRs: safest first, riskiest last (cutovers, destructive steps and behavior changes at the top), so a revert isolates the risk.
- Enforcement: git pre-commit and pre-push hooks and Claude Code hooks, all backed by `scripts/clean-code/`. A blocked commit or push means fix or split, not bypass.
- Check size anytime: `scripts/clean-code/check-mr-size.sh`
