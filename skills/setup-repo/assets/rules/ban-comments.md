# Ban comments

Code ships with no comments. A name, a type, or an extracted function says it instead.

**Scope:** every language, every line you add or touch, tests included. Generated code and lines you did not touch are out.

## Instead of a comment

| You were about to write | Do this |
| --- | --- |
| What the next block does | Extract a named function. The call is the sentence. |
| What a value means | Name the constant. |
| What a name means | Rename it. |
| A section banner | Order the file: public API first, helpers below. |
| Why an empty catch is fine | Call a named helper such as `ignoreOptionalFailure(err)`. |
| What changed in this diff | Write the code as it works now. History goes in the commit message. |
| Why a design was chosen, a quirk, a tradeoff | A dated doc ([docs-current-or-dated.md](docs-current-or-dated.md)) or the commit message. |
| `TODO` / `FIXME` | The tracker. |
| What a function returns or accepts | The type and the name. |
| An example of usage | A test. |

## Allowed: machine-read lines, not prose

| Shape | Example |
| --- | --- |
| Shebang | `#!/usr/bin/env bash` |
| License header | `// SPDX-License-Identifier: MIT`, `Copyright …` |
| Tool directive with a reason after `--` | `// eslint-disable-next-line no-empty -- empty probe is the signal` |
| Compiler or type directive | `// @ts-expect-error -- upstream type is wrong`, `# type: ignore[x] -- …`, `//go:build` |

A bare directive with no reason is a comment and is blocked.

## Repo override

A repo that publishes a library whose reference docs are generated from doc comments states that in its `AGENTS.md`. Only the generated-doc comments on the public API are then allowed.

## Enforcement

- `code-quality-check.sh` blocks added comments on every edit (`PostToolUse`), at `Stop`, and at pre-commit; `check-clean-code.sh` and `lint-clean-code.sh BASE` block them too.
- `CLEAN_CODE_SKIP=1` is denied by the git guard; fix the code instead.
