### Commit and ship

Default: commit every green change, push, open or update the MR/PR ([commit-and-ship](https://github.com/CodyTVWeber/Public-AI/blob/main/rules/commit-and-ship.md)).

- Low-risk repo (`.mr-size` `risk: low`): merge finished work the user asked for without extra approval
- Other repos: the repo's normal approval before merge

`scripts/guard/git-approval-guard.sh`: low-risk repo → allows commit, push, merge; denies force push. Elsewhere asks before commit and push. Always denies `--no-verify`, `core.hooksPath` overrides, `CLEAN_CODE_SKIP`, `SKIP`, `HUSKY=0`.
