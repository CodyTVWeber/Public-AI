# Research on latest default branch

Research (reading code, tracing behavior, comparing impls, "does X exist / how does X work") almost always needs latest `master`/`main`. Local checkouts go stale and mislead: modules renamed or removed upstream while the clone lags many commits.

- Before researching: `git fetch origin <default-branch>`, then read `origin/<default-branch>` (`git show`, `git ls-tree`, `git grep <ref>`) or a fresh clone. Never trust working tree alone
- `git status -sb` shows `behind N`; N > 0 → read remote ref
- Don't pull or merge into user's checkout to research; read the ref
- Exceptions: branch, MR, tag, or commit user named; user's uncommitted work
- Report ref and commit read from when conclusion depends on it
