# Scripting languages

Scripts are Bash or JavaScript. Nothing else.

| Need | Use |
|---|---|
| Shell glue, hooks, short pipelines | Bash |
| Any other script or program logic (replaces Python, Ruby, Perl, PHP, Lua, Go) | JavaScript: Node ESM `.mjs` |

## JavaScript

- Built-ins first: `node:fs`, `node:child_process`, `node:test`, `node:assert`, `fetch`
- Dependency only when built-ins can't do it
  - Pin exact version, no ranges
  - Commit lockfile with integrity hashes
  - Install with `npm ci --ignore-scripts`
  - `package.json` scoped to that tool's dir; `node_modules/` gitignored
- Tests: `*.test.mjs` run by `node --test`

## Exceptions

- Vendored standalone tool shipped in another language (example: `localvoice`)
- File a tool requires in its own language (a `Gemfile`, a `conftest.py` for a Python-only framework)

## Enforcement

- `scripts/lint/check-languages.sh --staged | --range REV`: fails when added files use another language's extension
- Repo `.languageexempt`: one path regex per line, skipped
- Runs in git `pre-commit` (after clean-code)
