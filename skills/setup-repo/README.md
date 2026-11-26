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
skills/setup-repo/scripts/bootstrap.sh   /path/to/repo --local --apply --yes   # same guardrails, tracked files unchanged
skills/setup-repo/scripts/verify-repo.sh /path/to/repo      # hooks active, settings valid, analyzer bites, drift
```

Then wire the linter snippet for the stack (SKILL.md step 7). Output contract: JSON on stdout, text on stderr;
exit 0 ok, 1 check failed, 2 usage, 3 precondition.

## Profiles

| Profile | Installs |
|---|---|
| `minimal` | rules, clean-code scripts, git pre-commit and pre-push hooks, AGENTS.md section (floors, and that a miss fails the check) |
| `standard` (default) | minimal + Claude Code hooks (PreToolUse guard, PostToolUse git check, PostToolUse analyzer and docs lint, Stop analyzer) + core skill symlinks |
| `factory` | standard + `ci` + `ai-risk` + `pr-template` (no approval gate: factories run unattended) |
| `local` (alias `--local`) | standard guardrails without changing tracked files; see Local profile |

## Flags

| Flag | Meaning |
|---|---|
| `--plan` / `--apply` | print the JSON plan (default) / execute it |
| `--profile minimal\|standard\|factory\|local`, `--local` | starting feature set; `--local` is `--profile local` |
| `--with a,b` / `--without a,b` | add or drop features: `rules`, `git-hooks`, `claude-hooks`, `post-git-hook`, `agents-doc`, `skills`, `ci`, `ai-risk`, `pr-template`, `approval-gate`, `privacy`, `research-ref` |
| `--hooks-via auto\|githooks\|husky\|lefthook\|precommit\|none` | git hook adapter; `auto` follows `detect-repo.sh` |
| `--skills SET`, `--skills-from PATH` | skill set and the Public-AI clone to link from (`PATH`, else `$PUBLIC_AI_DIR`; with neither, the skills step is a `manual` step) |
| `--upgrade` | re-apply only files whose source changed since install; locally modified files are kept and reported |
| `--force` | overwrite differing files (default: keep and report a `manual` step) |
| `--yes` | apply on a working tree with uncommitted changes |

Skill sets: `core` (default: `write-plan`, `align`, `implement`, `review`, `watch`, `plan-implement-review-watch`, plus the support skills they call: `plan-implement-review`, `verify-change`, `monitor` and the twelve `review-*` stage skills),
`core+aliases` (core plus the one-line aliases `pirw`, `ir`, `irw`, `rw`, `pi`, `pir`, `review-watch`, `implement-review`,
`implement-review-watch`, `plan-implement`, `plan`, `apirw`, `apirwm`, `code-review`), `all` (every skill with a `SKILL.md`), `none`, or a comma list of names.
Aliases overlap plugin skills of the same name, so they stay opt-in. One `.git/info/exclude` entry per link
(`.claude/skills/<name>`) hides the links and leaves the team's own skills visible; entries of removed links drop on the next run.

Add-ons: `ci` (job file that runs the installed scripts), `ai-risk` (risk tiers, merge policy `conservative`,
auto-merge off, tier scripts), `pr-template` (the verify-change body as the forge's template plus
`check-pr-body.sh`), `approval-gate` (commit and push need approval; for human-gated repos), `privacy`
(generic privacy gate; employer names and hostnames go in the untracked `<git-dir>/info/privacy-patterns`, one extended regex per line; `--strict` or `PRIVACY_REQUIRE_PATTERNS=1` blocks when it is missing), `research-ref` (SessionStart report when the checkout is behind).

## Local profile

`--profile local` installs the same guardrails without changing a tracked file, for repos where the team has not agreed to them.

| Piece | Standard | Local |
|---|---|---|
| Claude hooks | `.claude/settings.json` | `.claude/settings.local.json` |
| Git hooks | `.githooks` plus `core.hooksPath` (or the detected system) | `.git/hooks` only; `core.hooksPath` is never set, and an existing one makes git hooks a `manual` step |
| AGENTS.md section | written | not written; the note goes to `.git/info/local-guardrails.md` |
| Install record | `.claude/ai-guardrails.json` | `.git/info/local-guardrails.json` |
| Installed paths | tracked once committed | each one in `.git/info/exclude` (scripts as one directory, rules per file) |
| `ci` add-on | allowed | refused: it edits `.gitlab-ci.yml` or adds a workflow |

`verify-repo.sh` reads the record, checks `settings.local.json` and the note, and fails `local-clean` when an installed path shows in `git status`.

## Drift and upgrade

The install record holds the source repo's commit (`git rev-parse HEAD`, else `unknown`), the profile and features, and a SHA-256 per installed file.
`verify-repo.sh` reports `drift: [{path, status}]` with `changed-upstream` (source differs, installed file untouched), `modified-locally` (installed file differs from the record), `removed-upstream` (source file deleted, installed file untouched) and `missing`.
`bootstrap.sh --apply --upgrade` re-applies only `changed-upstream` files; `modified-locally` files stay untouched and appear as `manual` steps and notes until `--force`.
Record-less upgrade: a differing file whose blob matches a past upstream version (`stale-copy`) is replaced by `--upgrade`.
A plain re-run keeps every differing file and names `--upgrade` in the step reason.

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
- Skill links are local (one `.git/info/exclude` entry each): a fresh clone relinks with `link-skills.sh`; there is no default clone path, so set `PUBLIC_AI_DIR` or pass `--skills-from`

## Bare install

```bash
skills/setup-repo/scripts/install.sh /path/to/repo
```

The only code that copies files into a target; `bootstrap.sh` decides, merges JSON and AGENTS.md, and calls it for every copy (core files and add-ons).
Installs rules, scripts, `.githooks`, Claude hooks, and an appended "Clean code and small MRs" section. Flags: `--force`,
`--no-claude-hook`, `--claude-hooks LIST`, `--no-post-git`, `--no-githooks`, `--no-rules`, `--no-doc`, `--dry-run`,
`--copy SRC DEST` (copy-only mode, repeatable), `--overwrite DEST` (replace one differing file). Stdout is a JSON report; each file lists its `src`.

## Use as a skill

Symlink or copy this directory to your agent's skills folder, then ask: "set up this repo". SKILL.md is the playbook.

The AGENTS.md section (local: `.git/info/local-guardrails.md`) states these floors and that a miss fails the check, so the agent sees them while editing. Claude Code also loads `.claude/rules/`.

## What it enforces

| Gate | When | Blocks on |
|---|---|---|
| `pre-commit` | each commit | A large file that grows past the hard cap; empty catch blocks; an added comment (tests included); every analyzer error on staged lines |
| Analyzer hook | agent edits a file (`PostToolUse`) | Analyzer errors on that file's changed lines come back as feedback (exit 2); warnings arrive as `additionalContext`; the file joins the session edit log |
| Analyzer stop hook | agent finishes a turn (`Stop`) | Analyzer errors on the files edited this session (tracked files with changes when no log exists), exit 2 once; `stop_hook_active` true exits 0, so the agent never loops |
| `pre-push` | each push | Branch over the hard MR size (default 800 changed lines; documentation and repo-support files omitted) |
| Git post-check hook | agent ran `git commit`, `push`, `merge` or `pull` (`PostToolUse` on Bash) | Never blocks the finished command and always exits 0; analyzer errors on the commit's lines (`--range PARENT..HEAD`) or conflict-resolved files, subject over 72 chars, branch size, one-PR and watch reminder after push, conflicts left by a merge all go out as `additionalContext` |
| Claude Code guard | agent runs push or MR/PR create (`PreToolUse` on Bash) | Same size check, plus analyzer errors on `merge-base..HEAD` read through `--range` (never the working tree); exit 2 to the agent |
| Docs lint hook | agent edits a `.md` file | Time-relative wording in current docs; edits to dated docs, exit 2 to the agent |
| Linter snippets | lint step | Nesting, params, function size, parameter mutation |

Env knobs: `MR_SIZE_SOFT`, `MR_SIZE_HARD`, `FILE_SOFT`, `FILE_HARD`, `MR_BASE`; one-off bypass
`CLEAN_CODE_SKIP=1` (or `CC_SKIP=1`).

## Code-quality analyzer

`scripts/clean-code/code-quality-check.sh` runs a Node built-ins-only package
(`cleancode/`) through `node`. Findings count only when the offending line, or any line of the
offending function, changed against `HEAD` (the whole file when it is untracked or added), so existing
debt stays silent.

| Mode | Checks |
|---|---|
| `FILE...` | each file against `HEAD`; `--all-lines` audits every line |
| `--staged` | the index against `HEAD`, reading staged content |
| `--changed [BASE]` | working tree and untracked files against `BASE` (default `HEAD`) |
| `--range BASE..HEAD` | committed changes only, reading the text at the end ref: no working tree, no untracked files; `BASE...END` uses the merge base; push gates and the post-git check call it |
| `--hook` | `PostToolUse` stdin JSON: `tool_input.file_path` only; the path joins the session edit log |
| `--stop-hook` | `Stop` stdin JSON: the files in the session edit log that still exist (tracked files with changes when there is no log); `stop_hook_active` true exits 0 |
| `--list-rules` | the rule catalog as JSON |

Output: JSON `{findings:[{file,line,rule,severity,message,fix_hint}],summary}` on stdout, human text on stderr.
Exit: 0 clean (warnings allowed), 1 errors, 2 usage, 3 precondition (not a repo, bad `BASE`). Hook modes print
only hook protocol output: exit 2 plus stderr feeds errors back to the agent; warnings go out as
`additionalContext` (`PostToolUse`) or `systemMessage` (`Stop`).

| Rule | Severity | Fires on |
|---|---|---|
| `added-comment` | error | any comment except shebang, SPDX/Copyright, `//go:build`-style directives, and tool directives with a reason after `--`; a Python docstring on a module, class or function is a warning (`docstring`), a free-floating string used as a comment stays an error |
| `todo-marker`, `banner` | error | TODO/FIXME/XXX in a comment; `STATUS:` or `====` banner lines |
| `empty-catch` | error | empty `catch` / `except` body (`pass` and `...` count as empty) |
| `param-count` | error / warn | 4+ params / 3 params (`self`, `cls`, `this` excluded; shell counts the highest `$N`) |
| `function-length` | error / warn | over 80 / over 40 lines of logic (blank and comment lines excluded) |
| `nesting-depth` | error / warn | 4+ / 3 nested control-flow blocks inside one function |
| `file-size` | error / warn | 400+ / over 200 lines, only when the change grows the file |
| `param-mutation` | error / warn | `param.x = …`, `param[i] = …`, `param += …` (JS/TS, Python, Kotlin, Java, C#, Scala); warn for `res`, `req`, `ctx`, `event`, `self`, `this`, `ref.current`; functions named `set*`, `fill*`, `apply*`, `update*`, `init*` and similar are exempt |
| `bool-flag-param` | warn | boolean parameter named `is*`, `has*`, `should*`, `enable*` |
| `magic-number` | warn | numeric literal other than -1, 0, 1, 2 outside constants, enum members, default arguments, index or slice brackets, annotations, exit calls |
| `duplicate-string` | warn | same string of 6+ characters three or more times in a file |
| `inline-try-catch` | warn | try/catch of 5+ lines inside a function longer than 10 lines |
| `layer-folder` | warn | added file under a `controller`, `service` or `model` folder |
| `function-order` | warn | caller below its callee, or a private helper above a public function in the same block. Cycles skipped. JS public means `export` on the header; Go an initial capital; Rust `pub`; Python and Ruby a leading `_` that is not a dunder; other brace languages `private` or `protected`. Shell has no public marker |
| `guard-clause` | warn | one `if` with no `else` holds the whole body of a function of 8 or more logic lines (Python and brace languages) |

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
- `function-order` compares functions at the same indent with no lesser-indent line between them, so a method does not order against a function in another class. Shell calls are command words.
- Judgment left for review: one definition per business rule, names that match docs.

## Layout

```
SKILL.md                    agent playbook
scripts/detect-repo.sh      read-only repo profile and recommendation
scripts/bootstrap.sh        plan and apply by profile and flags
scripts/verify-repo.sh      post-install checks
scripts/link-skills.sh      symlink skills from a Public-AI clone
scripts/install.sh          the one file writer (rules, scripts, hooks, add-on copies)
scripts/lib/                Node modules behind the wrappers (setuplib/*.mjs)
assets/rules                clean-code.md, ban-comments.md, docs-current-or-dated.md, small-mrs.md, research-latest-main.md
assets/scripts              check-mr-size.sh, check-mr-size-app.sh, check-mr-size-support.sh, check-mr-size-docs.sh,
                            check-clean-code.sh, claude-pre-tool-guard.sh, post-git-check.sh,
                            pre-push-gate.sh, git-scan.sh, lint-docs.sh, code-quality-check.sh
assets/scripts/cleancode    the analyzer package (lexer, language structure, rules, git diff, hooks, CLI)
assets/scripts/gitscan      shared git-command scanner used by the guards and the post-git check
assets/githooks             pre-commit, pre-push, commit-msg
assets/ci                   GitLab and GitHub job templates
assets/lint                 eslint, detekt, ruff snippets
assets/AGENTS.guardrails.md section template; assets/skills-manifest.json core and alias skill lists
```
