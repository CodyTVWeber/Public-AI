# public-ai-sync

NPM **dev dependency** that copies a public AI pack (rules, skills, and related config) into a consuming repo on install.

## Install

```sh
npm install --save-dev public-ai-sync
```

`postinstall` (and `prepare`) fetch the source, replace the target folder, and append a `.gitignore` line for that folder.

Default target: `.public-ai/`
Default source: `https://github.com/CodyTVWeber/Public-AI`
Default paths: `rules`, `skills`, `AI-setup`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude`, `.func-size`, `.mr-size`

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

`source` is a git URL or a local directory.

## Gitignore

The package ships `gitignore.snippet`. `npx public-ai-sync ignore` appends the target path if it is missing.

## Failures

A missing network, a failed clone, or an empty source exits non-zero and leaves the previous target folder in place.

## Manual run

```sh
npx public-ai-sync
```
