# Ban comments

New and moved production code ships with no comments. A name or a helper is the documentation.
The pre-commit check blocks an added comment. This file is the rule. `clean-code.md` points here.

**Scope:** production code you add or move. Tests, generated code, and declaration files are out
of the check. Untouched comments can stay until you touch that line.

## Instead of a comment

| You were about to write | Do this |
| --- | --- |
| What the next block does | Extract a named function. The call is the sentence. |
| What a value means | Name the constant. |
| What a bad name means | Rename it. |
| A section banner | Order the file: public API on top, helpers below. |
| `ignore` on an empty catch | Call a named helper such as `ignoreOptionalFailure(err)`. |
| What changed in this diff | Say how the code works now, in the name. History belongs in the commit. |

## Always blocked

- Narration that restates the line or the signature
- Banners (`====`, `----`, `SECTION`)
- `ignore` comments
- `STATUS:` and other notes about a migration or a previous version
- `TODO` and `FIXME` left in the line you are adding

## Allowed, one line, on purpose

The check allows only these shapes. Anything else fails the commit.

| Shape | Example |
| --- | --- |
| External quirk | `// quirk: the clock can step backward` |
| Security note | `// security: compare in constant time` |
| Measured tradeoff | `// tradeoff: one allocation avoids a second scan` |
| Lint or type disable with a reason | `// eslint-disable-next-line no-empty -- empty probe is the signal` |
| License line | `// SPDX-License-Identifier: MIT` or a `Copyright` line |

The reason is part of the line. A bare disable, with no words after the rule, is still blocked.

`CLEAN_CODE_SKIP=1` skips the check for one command. Say why in the commit message.
