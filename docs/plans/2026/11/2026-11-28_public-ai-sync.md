# Public AI NPM sync package

Date: 2026-11-28
**Branch:** `cursor/public-ai-sync-53e6`
**Status:** implemented

## Context

`/idea-to-production` on this repo: ship a publishable NPM **dev dependency** that copies this pack's AI files into a consuming repo on install. Align skipped: `assess.sh` size small, vagueness low; the user already named the package, postinstall, version bump, and dummy validator.

Read from: `origin/main` `71ad598`.

Do not add an `idea-to-production` skill file. The chain is the process for this build, not a catalog row.

Related: `skills/setup-repo` copies guardrails into tracked paths. This package is a different distribution: a gitignored regenerated folder.

No production deploy in this change: monitoring skipped.

## Terms

| Term | Meaning |
| --- | --- |
| sync package | `packages/public-ai-sync`, NPM name `public-ai-sync` |
| consumer | Repo that lists the sync package as a dev dependency |
| source | Git URL or local directory of the public AI pack |
| target folder | Regenerated AI folder in the consumer, default `.public-ai` |
| dummy validator | `test-consumer/`, file-linked to the sync package |

## Decisions

| Decision | Choice | Rejected |
| --- | --- | --- |
| How files arrive | postinstall fetches source, then atomic replace of the target | Bundling a snapshot only; mutating tracked `AGENTS.md` like setup-repo |
| Where they land | Consumer target folder, gitignored | Writing into the consumer's committed tree |
| Fetch fail | Exit non-zero, leave the previous target in place | Wipe-then-fill; silent skip |
| Version signal | GitHub Action patch-bumps the package when AI paths change | semantic-release (pinned deps); bumping on every commit |
| Proof | `test-consumer` + plan-folder script | Skill-catalog row for idea-to-production |

## Why this approach

Dependabot/Renovate see a version bump and reinstall. postinstall then pulls current source. Atomic staging keeps a failed fetch from leaving a half-written folder. A file: consumer is the loop a person can run without publishing.

## Concrete steps

1. Add `packages/public-ai-sync`: ESM package, `bin/public-ai-sync`, `postinstall` and `prepare` both run `node bin/sync.mjs`. Default source `https://github.com/CodyTVWeber/Public-AI` (no `.git` suffix), default target `.public-ai`, default paths `rules`, `skills`, `AI-setup`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude`, `.func-size`, `.mr-size`. Override via consumer `package.json` field `publicAiSync` or `PUBLIC_AI_SYNC_SOURCE` / `_REF` / `_TARGET` / `_PATHS` / `_SKIP` / `_ROOT`
2. Sync: resolve consumer root (`PUBLIC_AI_SYNC_ROOT`, else `INIT_CWD`, else `npm_config_local_prefix`). Skip exit 0 when skip env is set, when the consumer package name is `public-ai-sync`, or when `packages/public-ai-sync/package.json` exists under the consumer root (this repo) unless that consumer sets `publicAiSync`. Fetch git URL with `git clone --depth 1` or copy a local directory. Copy only configured paths into a staging dir. Empty staging → fail, target untouched. Then write `target.next`, rename existing target to `target.prev`, rename next into place, remove prev. Clone or copy failure → named error, target untouched
3. Gitignore: ship `gitignore.snippet`; postinstall and `public-ai-sync ignore` append the target path to the consumer `.gitignore` when missing
4. Version bump: `.github/workflows/public-ai-sync-bump.yml` on push to `main` for AI paths and `packages/public-ai-sync/**` except the package version file. `packages/public-ai-sync/scripts/bump.mjs` patch-increments, commits, tags, pushes. `npm publish --access public` only when `NPM_TOKEN` is set; otherwise print skip. Skip when HEAD subject already starts with `chore: bump public-ai-sync`. Only `actions/checkout@v4`
5. Dummy validator: `test-consumer/` depends on `file:../packages/public-ai-sync`, `publicAiSync.source` = `./ai-source` (fixture with `rules/`, `skills/`, `AGENTS.md`), target `.public-ai` gitignored. `test-consumer/README.md` and `scripts/tests/public-ai-sync-consumer.test.sh` run: install, assert files landed, change fixture, reinstall/sync, assert replacement. Unit tests in `scripts/tests/public-ai-sync.test.mjs`
6. Privacy: `.privacyexempt` version lines for the package, consumer, tests, workflow, and this plan. Root `.gitignore` ignores `node_modules/` and `.public-ai/`. One row in root `README.md` pointing at the package. No idea-to-production `SKILL.md`

## Acceptance criteria

- AC-1: `npm install` in `test-consumer/` fills `.public-ai` with the fixture's `rules`, `skills`, and `AGENTS.md`
- AC-2: a failed fetch prints a clear error, exits non-zero, and leaves an existing target folder in place
- AC-3: the consumer target path is gitignored, and the package can append that snippet
- AC-4: empty source (configured paths missing or vacant) exits non-zero and does not replace the target
- AC-5: after the fixture changes, a second install or `npx public-ai-sync` replaces the target contents
- AC-6: the bump workflow and `bump.mjs` patch-increment the package on AI-path changes and skip publish when `NPM_TOKEN` is unset

## Risks

- (non-blocking) First npm publish needs an `NPM_TOKEN` secret; this change ships the gate, not a registry release
- (non-blocking) Workspace `npm install` at repo root skips sync; the dummy validator runs from `test-consumer/`

## Out of scope

- An `idea-to-production` skill file or catalog row
- Replacing `setup-repo` / `AI-setup`
- Publishing to the npm registry in this run
- semantic-release or extra GitHub Actions beyond checkout

## Verification

| Layer | Cases | AC | Observable | Writer |
| --- | --- | --- | --- | --- |
| system | happy | AC-1 | `npm install` in `test-consumer` creates `.public-ai/AGENTS.md` matching the fixture | script |
| system | happy | AC-3 | after install, `test-consumer/.gitignore` lists `.public-ai/` | script |
| system | happy | AC-5 | after the fixture gains a file and drops another, a second sync leaves only the later tree | script |
| api | critical | AC-2 | sync against an unreachable git URL exits non-zero and keeps the previous target files | script |
| api | critical | AC-4 | sync against a directory with none of the configured paths exits non-zero and keeps the previous target files | script |
| api | happy | AC-6 | `bump.mjs --dry-run` prints the next patch version and skip-publish when `NPM_TOKEN` is unset | script |
