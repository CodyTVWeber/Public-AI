# Research on the latest default branch

Research (reading code, tracing behavior, comparing implementations, "does X exist / how does X
work") almost always needs the latest `master`/`main`. Local checkouts go stale and mislead:
modules get renamed or removed upstream while the clone sits many commits behind.

- Before researching a repo: `git fetch origin <default-branch>`, then read from
  `origin/<default-branch>` (`git show`, `git ls-tree`, `git grep <ref>`), or a fresh clone. Never
  trust the working tree alone
- Check `git status -sb` for `behind N`; any N > 0 means read from the remote ref
- Do not pull or merge into the user's checkout just to research; read the ref instead
- Exceptions: a specific branch, MR, tag or commit the user named, or the user's uncommitted work
- Report the ref and commit you read from when a conclusion depends on it
