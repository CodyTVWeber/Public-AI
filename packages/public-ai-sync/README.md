# public-ai-sync

NPM **dev dependency** that installs this pack's AI environment into a consuming repo: rules, skills, agent files, Claude hooks, scripts (lint, guard, privacy, git hooks), and code-quality runners.

## Install

```sh
npm install --save-dev public-ai-sync
```

`postinstall` and `prepare` fetch the source, replace the target folder, link boot paths at the consumer root, append `.gitignore` lines, install git hooks when the consumer is a git repo, and add `public-ai:*` npm scripts.

Default target: `.public-ai/`
Default source: `https://github.com/CodyTVWeber/Public-AI`
Default paths: `rules`, `skills`, `AI-setup`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `PRIVACY.md`, `.claude`, `.func-size`, `.mr-size`, `scripts`

## What install does

1. Copy the default paths into the target folder (atomic replace: staging, then swap)
2. Create relative symlinks at the consumer root so `$CLAUDE_PROJECT_DIR` hooks resolve. `.claude`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `PRIVACY.md`, `rules`, `skills`, `AI-setup`, `.func-size`, and `.mr-size` link as a whole when those names are free. `scripts/` stays a real directory; each child (`lint`, `guard`, `check-privacy.sh`, `install-hooks.sh`, `tests`, …) is linked. An existing non-link file is left in place
3. Gitignore the target and every link this package created
4. Run `scripts/install-hooks.sh` when that script is present. A consumer that is not a git repo, or that already has a foreign hook plus a `.bak`, does not fail the install
5. Add `public-ai:*` npm scripts when those names are free: `public-ai:sync` (manual re-run), `public-ai:lint-docs`, `public-ai:lint-explainer`, `public-ai:lint`, `public-ai:check-languages`, `public-ai:check-copies`, `public-ai:check-duplicates`, `public-ai:check-skill-catalog`, `public-ai:check-1k-cross`, `public-ai:verdict-parse`, `public-ai:code-quality`, `public-ai:privacy`, and `public-ai:install-hooks`. Consumer `postinstall` and `prepare` scripts are not added

## Config

Consumer `package.json`:

```json
{
  "publicAiSync": {
    "source": "https://github.com/CodyTVWeber/Public-AI",
    "ref": "main",
    "target": ".public-ai",
    "paths": ["rules", "skills", "AGENTS.md"]
  }
}
```

Env (wins over `package.json`): `PUBLIC_AI_SYNC_SOURCE`, `PUBLIC_AI_SYNC_REF`, `PUBLIC_AI_SYNC_TARGET`, `PUBLIC_AI_SYNC_PATHS` (comma list), `PUBLIC_AI_SYNC_ROOT`, `PUBLIC_AI_SYNC_SKIP=1`.

`source` is a git URL or a local directory. Omit `paths` to take the full default list.

## Gitignore

The package ships `gitignore.snippet`. `npx public-ai-sync ignore` appends the target path if it is missing. A full sync also ignores wired boot paths.

## Failures

A missing network, a failed clone, or an empty source exits non-zero and leaves the previous target folder in place.

## Manual run

```sh
npx public-ai-sync
npx public-ai-sync ignore
npx public-ai-sync lint-docs
npx public-ai-sync lint-explainer
npx public-ai-sync lint
npx public-ai-sync check-languages
npx public-ai-sync check-copies
npx public-ai-sync check-duplicates
npx public-ai-sync check-skill-catalog
npx public-ai-sync check-1k-cross
npx public-ai-sync verdict-parse
npx public-ai-sync code-quality
npx public-ai-sync privacy
npx public-ai-sync install-hooks
```
