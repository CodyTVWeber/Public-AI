# Ban comments

Code ships with no comments. A name, a type, or an extracted function says it instead.

**Scope:** every language, every line added or touched, tests included. Generated code and untouched lines are out.

## Instead of a comment

| Would write | Do this |
| --- | --- |
| What the next block does | Extract named function. The call is the sentence |
| What a value means | Name the constant |
| What a name means | Rename it |
| Section banner | Order file: public API first, helpers below |
| Why an empty catch is fine | Call named helper, e.g. `ignoreOptionalFailure(err)` |
| What changed in this diff | Write code as it works now. History → commit message |
| Why a design, quirk, tradeoff | Dated doc ([docs-current-or-dated.md](docs-current-or-dated.md)) or commit message |
| `TODO` / `FIXME` | The tracker |
| What a function returns or accepts | The type and the name |
| Usage example | A test |

## Allowed: machine-read lines, not prose

| Shape | Example |
| --- | --- |
| Shebang | `#!/usr/bin/env bash` |
| License header | `// SPDX-License-Identifier: MIT`, `Copyright …` |
| Tool directive with reason after `--` | `// eslint-disable-next-line no-empty -- empty probe is the signal` |
| Compiler or type directive | `// @ts-expect-error -- upstream type is wrong`, `# type: ignore[x] -- …`, `//go:build` |

Bare directive with no reason = comment, blocked.

## Repo override

Repo publishing a library whose reference docs are generated from doc comments states that in its `AGENTS.md`. Then only generated-doc comments on the public API are allowed.

## Enforcement

- `code-quality-check.sh` blocks added comments: every edit (`PostToolUse`), at `Stop`, at pre-commit. `check-clean-code.sh` and `lint-clean-code.sh BASE` block them too
- `CLEAN_CODE_SKIP=1` denied by git guard. Fix the code instead
