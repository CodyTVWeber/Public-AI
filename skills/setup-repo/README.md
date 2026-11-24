# setup-repo

Bootstraps a whole repo with the AI guardrails, shaped to what the repo already has: clean-code rules and
analyzer, git hooks, Claude Code hooks on git commands (before and after), an AGENTS.md section, and skill
links from a Public-AI clone. Pipeline pieces are opt-in. Works with any agent that can run a shell; the
Claude Code hooks are optional.

## Fast start

```bash
skills/setup-repo/scripts/detect-repo.sh /path/to/repo      # read-only profile + recommendation
skills/setup-repo/scripts/bootstrap.sh   /path/to/repo      # plan (default): writes nothing
skills/setup-repo/scripts/bootstrap.sh   /path/to/repo --apply --yes
skills/setup-repo/scripts/verify-repo.sh /path/to/repo      # hooks active, settings valid, analyzer bites
```

Then wire the linter snippet for the stack (SKILL.md step 7). Output contract: JSON on stdout, text on stderr;
exit 0 ok, 1 check failed, 2 usage, 3 precondition.

## Profiles

| Profile | Installs |
|---|---|
| `minimal` | rules, clean-code scripts, git pre-commit and pre-push hooks |
| `standard` (default) | minimal + Claude Code hooks (PreToolUse guard, PostToolUse git check, PostToolUse analyzer and docs lint, Stop analyzer) + AGENTS.md section + core skill symlinks |
| `factory` | standard + `ci` + `ai-risk` + `pr-template` (no approval gate: factories run unattended) |

## Flags

| Flag | Meaning |
|---|---|
| `--plan` / `--apply` | print the JSON plan (default) / execute it |
| `--profile minimal\|standard\|factory` | starting feature set |
| `--with a,b` / `--without a,b` | add or drop features: `rules`, `git-hooks`, `claude-hooks`, `post-git-hook`, `agents-doc`, `skills`, `ci`, `ai-risk`, `pr-template`, `approval-gate`, `privacy`, `research-ref` |
| `--hooks-via auto\|githooks\|husky\|lefthook\|precommit\|none` | git hook adapter; `auto` follows `detect-repo.sh` |
| `--skills core\|all\|none`, `--skills-from PATH` | skill set and the Public-AI clone to link from (default `$PUBLIC_AI_DIR`, else `~/code/Public-AI`) |
| `--force` | overwrite differing files (default: keep and report a `manual` step) |
| `--yes` | apply on a working tree with uncommitted changes |

Add-ons: `ci` (job file that runs the installed scripts), `ai-risk` (risk tiers, merge policy `conservative`,
auto-merge off, tier scripts), `pr-template` (the verify-change body as the forge's template plus
`check-pr-body.sh`), `approval-gate` (commit and push need approval; for human-gated repos), `privacy`
(generic privacy gate, employer pattern empty), `research-ref` (SessionStart report when the checkout is behind).

## Adapter matrix

| Hook system found | Adapter action |
|---|---|
| none | `.githooks/` plus `core.hooksPath=.githooks` |
| foreign hooks in `.git/hooks` | chained: kept as `<name>.bak`, run after the checks |
| `core.hooksPath` elsewhere | never overridden; `manual` step lists the calls |
| husky | call lines appended to `.husky/pre-commit` and `pre-push` (created when absent) |
| lefthook, pre-commit framework | `manual` step with the exact snippet; the YAML is never rewritten |
| `--hooks-via none` | nothing; the repo's setup calls `scripts/clean-code/*` |

| Forge | CI adapter (`ci` add-on, on in `factory`) |
|---|---|
| GitLab | `.gitlab/ci/ai-guardrails.yml`; an `include` line is added to `.gitlab-ci.yml` (created when absent; a non-list `include:` becomes a `manual` step) |
| GitHub | `.github/workflows/ai-guardrails.yml` as its own workflow; existing workflows stay untouched |
| other or none | `manual` step listing the commands |

The jobs call the installed `scripts/clean-code/*`, so CI and local hooks run the same code. CI is the control a PR
cannot silently delete: make the jobs required and protect the CI files with code owners.

## Limits

- Detection reads files and git config; it does not run the project's tools. Visibility needs `--probe-visibility` and `gh` or `glab`
- Commands are found from package scripts, Makefile targets, Python config and ecosystem defaults; nothing is executed
- lefthook, the pre-commit framework and simple-git-hooks are never edited: the plan prints the snippet
- An `include:` that is not a plain list, a differing file, or a foreign `core.hooksPath` becomes a `manual` step
- The analyzer checks changed lines only; legacy debt stays silent. Linter snippets are merged by hand
- Skill links are local (`.git/info/exclude`): a fresh clone relinks with `link-skills.sh`

## Bare install

```bash
skills/setup-repo/scripts/install.sh /path/to/repo
```

Core copier that `bootstrap.sh` calls: rules, scripts, `.githooks`, Claude hooks, and an appended
"Clean code and small MRs" section. Flags: `--force`, `--no-claude-hook`, `--claude-hooks LIST`, `--no-post-git`,
`--no-githooks`, `--no-rules`, `--no-doc`, `--dry-run`. Stdout is a JSON report.

## Use as a skill

Symlink or copy this directory to your agent's skills folder, then ask: "set up this repo". SKILL.md is the playbook.

## What it enforces

| Gate | When | Blocks on |
|---|---|---|
| `pre-commit` | each commit | A large file that grows past the hard cap; empty catch blocks; an added comment (tests included); every analyzer error on staged lines |
| Analyzer hook | agent edits a file (`PostToolUse`) | Analyzer errors on that file's changed lines, exit 2 to the agent; warnings arrive as `additionalContext` |
| Analyzer stop hook | agent finishes a turn (`Stop`) | Analyzer errors on every changed file, exit 2 once; `stop_hook_active` true exits 0, so the agent never loops |
| `pre-push` | each push | Branch over the hard MR size (default 800 changed lines) |
| Git post-check hook | agent ran `git commit`, `push`, `merge` or `pull` (`PostToolUse` on Bash) | Never blocks the finished command; analyzer errors on the commit's lines or conflict-resolved files exit 2 to the agent; subject over 72 chars, branch size, one-PR and watch reminder after push, conflicts left by a merge go out as `additionalContext` |
| Claude Code guard | agent runs push or MR/PR create (`PreToolUse` on Bash) | Same size check, plus analyzer errors on the branch's changed lines; exit 2 to the agent |
| Docs lint hook | agent edits a `.md` file | Time-relative wording in current docs; edits to dated docs, exit 2 to the agent |
| Linter snippets | lint step | Nesting, params, function size, parameter mutation |

Env knobs: `MR_SIZE_SOFT`, `MR_SIZE_HARD`, `FILE_SOFT`, `FILE_HARD`, `MR_BASE`; one-off bypass
`CLEAN_CODE_SKIP=1` (or `CC_SKIP=1`).

## Code-quality analyzer

`scripts/clean-code/code-quality-check.sh` runs a Python 3 standard-library package
(`cleancode/`) through `python3 -I`. Findings count only when the offending line, or any line of the
offending function, changed against `HEAD` (the whole file when it is untracked or added), so existing
debt stays silent.

| Mode | Checks |
|---|---|
| `FILE...` | each file against `HEAD`; `--all-lines` audits every line |
| `--staged` | the index against `HEAD`, reading staged content |
| `--changed [BASE]` | working tree and untracked files against `BASE` (default `HEAD`) |
| `--hook` | `PostToolUse` stdin JSON: `tool_input.file_path` only |
| `--stop-hook` | `Stop` stdin JSON: every changed file; `stop_hook_active` true exits 0 |
| `--list-rules` | the rule catalog as JSON |

Output: JSON `{findings:[{file,line,rule,severity,message,fix_hint}],summary}` on stdout, human text on stderr.
Exit: 0 clean (warnings allowed), 1 errors, 2 usage, 3 precondition (not a repo, bad `BASE`). Hook modes print
only hook protocol output: exit 2 plus stderr feeds errors back to the agent; warnings go out as
`additionalContext` (`PostToolUse`) or `systemMessage` (`Stop`).

| Rule | Severity | Fires on |
|---|---|---|
| `added-comment` | error | any comment except shebang, SPDX/Copyright, `//go:build`-style directives, and tool directives with a reason after `--` (docstrings included) |
| `todo-marker`, `banner` | error | TODO/FIXME/XXX in a comment; `STATUS:` or `====` banner lines |
| `empty-catch` | error | empty `catch` / `except` body (`pass` and `...` count as empty) |
| `param-count` | error / warn | 4+ params / 3 params (`self`, `cls`, `this` excluded; shell counts the highest `$N`) |
| `function-length` | error / warn | over 80 / over 40 lines of logic (blank and comment lines excluded) |
| `nesting-depth` | error / warn | 4+ / 3 nested control-flow blocks inside one function |
| `file-size` | error / warn | 400+ / over 200 lines, only when the change grows the file |
| `param-mutation` | error | `param.x = …`, `param[i] = …`, `param += …` (JS/TS, Python, Kotlin, Java, C#, Scala); functions named `set*`, `fill*`, `apply*`, `update*`, `init*` and similar are exempt |
| `bool-flag-param` | warn | boolean parameter named `is*`, `has*`, `should*`, `enable*` |
| `magic-number` | warn | numeric literal other than -1, 0, 1, 2 outside constants, enum members, default arguments, index or slice brackets, annotations, exit calls |
| `duplicate-string` | warn | same string of 6+ characters three or more times in a file |
| `inline-try-catch` | warn | try/catch of 5+ lines inside a function longer than 10 lines |
| `layer-folder` | warn | added file under a `controller`, `service` or `model` folder |

Test paths (`test/`, `tests/`, `spec/`, `fixtures/`, `*.test.*`, `*_test.*`, `test_*`, `*Test.*`) skip
`file-size`, `function-length`, `magic-number` and `duplicate-string`. Generated paths (`generated/`, `vendor/`,
`node_modules/`, `*.d.ts`, `*.min.js`, `*.pb.go`) skip everything. Other files are ignored.

Env: `CC_FUNC_WARN` (40), `CC_FUNC_ERROR` (80), `CC_PARAMS_ERROR` (4), `CC_NEST_WARN` (3), `CC_NEST_ERROR` (4),
`CC_FILE_WARN` (200), `CC_FILE_ERROR` (400), `CC_DISABLE=rule,rule@ext+ext`, `CC_SKIP=1` / `CLEAN_CODE_SKIP=1`
(prints that the run was skipped).

Languages: JS/TS (`js jsx mjs cjs ts tsx`), Java, Kotlin (`kt kts`), Go, Rust, C/C++ (`c h cc cpp hpp`), C#, Swift, PHP,
Scala, Python, bash/sh, Ruby.

Known limits (heuristics, not parsers):
- Functions come from header patterns. Anonymous callbacks are not separate functions: their lines count toward the enclosing
  function. Curried Scala definitions, C macros, and one-parameter arrows without parentheses are not detected.
- Regex literals that hold quotes or `//` can confuse comment and string masking for the rest of that line. PHP `#`
  comments and heredocs, Rust raw strings, and C# verbatim strings are not modeled.
- Shell: heredoc bodies are data, so `##` headings inside them are never comments. Nesting counts `if`, `for`, `while`,
  `until` and `case`; magic numbers are not checked; params are the highest positional `$N` used.
- Ruby: `def ... end` plus statement-initial keywords; modifier forms (`x if y`) do not nest.
- Nesting counts control flow only (`if`, `else`, `for`, `while`, `switch`, `when`, `try`, `catch`); lambdas and object
  literals do not count. `with` and `case` arms do not count.
- `param-mutation` cannot tell a local alias from a parameter and skips plain reassignment.
- Judgment items (callers above callees, one definition per rule, names match docs) stay with review.

## Layout

```
SKILL.md                    agent playbook
scripts/detect-repo.sh      read-only repo profile and recommendation
scripts/bootstrap.sh        plan and apply by profile and flags
scripts/verify-repo.sh      post-install checks
scripts/link-skills.sh      symlink skills from a Public-AI clone
scripts/install.sh          core copier (rules, scripts, hooks)
scripts/lib/                Python modules behind the wrappers (setuplib/)
assets/rules                clean-code.md, ban-comments.md, docs-current-or-dated.md, small-mrs.md, research-latest-main.md
assets/scripts              check-mr-size.sh, check-clean-code.sh, claude-pre-tool-guard.sh, post-git-check.sh,
                            pre-push-gate.sh, git-scan.sh, lint-docs.sh, code-quality-check.sh
assets/scripts/cleancode    the analyzer package (lexer, language structure, rules, git diff, hooks, CLI)
assets/scripts/gitscan      shared git-command scanner used by the guards and the post-git check
assets/githooks             pre-commit, pre-push, commit-msg
assets/ci                   GitLab and GitHub job templates
assets/lint                 eslint, detekt, ruff snippets
assets/AGENTS.guardrails.md section template; assets/skills-manifest.json core skill list
```
