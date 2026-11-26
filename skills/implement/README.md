# implement

AI-agnostic skill: implement from a plan (or ticket), lint/test, commit, push, and **ensure a PR exists** (create only if none already).

Sibling of [write-plan](../write-plan/). Used alone or as Phase B of [plan-implement-review](../plan-implement-review/).

If the work came from a **tracker task** (e.g. Asana), post one Implement rN comment — rules in [tracker-comments.md](../plan-implement-review/references/tracker-comments.md).

## Install

### Grok

```bash
ln -sfn <path-to-this-repo>/skills/implement ~/.grok/skills/implement
# SKILL.md → implement.md inside that dir
```

### Claude Code

```bash
cp <path-to-this-repo>/skills/implement/implement.md ~/.claude/commands/implement.md
# or symlink into a project .claude/skills/implement/SKILL.md
```

## Invoke

- `/implement`
- “Implement the plan at …”
- “Implement tracker task …”
- Automatically as implementer inside `/plan-implement-review`

## PR rule (same as write-plan)

Create a PR **only if** there is not already an open PR for this head branch / same ticket. Prefer **one PR** for plan + code. Git/PR steps call `skills/plan-implement-review/scripts/{forge-ctx,pr-find,fresh-branch}.sh` (repo-root-relative); outside this repo, install that `scripts/` dir too.

## Tracker comments

When the work came from a tracker task, post one short **Implement rN** progress comment per round. Format: [tracker-comments.md](../plan-implement-review/references/tracker-comments.md).

## Scripts

| Script | Use | Exit |
|---|---|---|
| `scripts/upload-evidence.mjs <project-id> <files> [--host H] [--dry-run]` | Upload png/jpg/gif/webp/mp4/webm to a GitLab project; JSON `{file: markdown}` | 2 bad input, 3 no token/host, 4 upload failed |
| `scripts/evidence-check.sh <files> [--before B --after A]` | Size, PNG dimensions, sha256; flags zero-byte, tiny, before = after | 1 problem |
| `scripts/proof-check.sh <body> <scope.json>` (scope from `plan-implement-review/scripts/diff-scope.sh`) | PR/MR body vs scope: headings, build, review guide, tier, media/curl/query/diagram counts | 1 `missing[]` |
| `scripts/slices-check.sh SLICES.json [--max-slices N]` | Slice names, count cap (default 4), non-empty paths, disjoint path globs; JSON `{ok, errors, overlaps}` | 1 invalid or overlap, 3 bad input |
| `scripts/worktree-split.sh --base B --topic T --slices a,b [--root D] [--mode worktree\|clone]` | One branch `B--<slice>` and one checkout per slice outside the repo; clean tree required; rolls back on failure; JSON `{slices:[{name,path,branch}]}` | 3 precondition or failure |
| `scripts/worktree-merge.sh --into B --topic T --slices a,b [--mode ...]` | `git merge --no-ff` each slice in order on B; stops at the first conflict; JSON `{merged, pending, conflict}` | 1 conflict, 3 wrong branch or dirty |
| `scripts/worktree-clean.sh --topic T [--into B] [--mode ...] [--force]` | Removes checkouts, deletes merged slice branches, prunes; unmerged or dirty slices stay unless `--force`; JSON `{removed, kept, discarded, worktrees_left}` | 1 kept or left |

## Parallel slices

Default is one implementer; worktrees only for parallel slices ([implement.md](implement.md) section "Parallel slices"). Tests: `scripts/tests/*.test.sh`.

1. List slices with disjoint paths in `SLICES.json`; run `scripts/slices-check.sh SLICES.json`.
2. `scripts/worktree-split.sh --base <feat> --topic <t> --slices a,b`; one subagent per printed `path`.
3. After they report: `scripts/worktree-merge.sh --into <feat> --topic <t> --slices a,b`; resolve a conflict, then merge `pending`.
4. Run the full gate once on `<feat>`.
5. `scripts/worktree-clean.sh --topic <t>`; `worktrees_left` must be 0. Add `--mode clone` to steps 2, 3 and 5 when worktrees are forbidden.
