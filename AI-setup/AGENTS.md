# Global Rules

Portable agent rules. This file is the source. `CLAUDE.md` only points here. Symlink both into the agent user dir (`~/.claude/AGENTS.md` and `~/.claude/CLAUDE.md`); other agents load this file from their user memory.

## Density

The reader is slow: structure output to minimize reading, not only word count.
All output, rules, and memory files carry full information in the fewest words.

- Bullets, outlines, and tables over prose paragraphs, including explanations, verdicts, and opinions
- Lead each bullet with the conclusion, not the setup
- Tables over lists of key-value pairs
- Bold the load-bearing phrase per bullet so the page skims
- No filler ("Great question!", "I'd be happy to…", trailing summaries)
- Deliver the complete result; skip repeated acknowledgements and process narration
- Skip what the code or diff already shows
- Skip examples unless the concept fails without one
- Brief for updates, thorough for new or complex work; thorough means more structure, not more prose

## Comments and docs

- No comments: [rules/ban-comments.md](../rules/ban-comments.md). Extract a named function or rename instead
- Docs are current state or a dated snapshot: [rules/docs-current-or-dated.md](../rules/docs-current-or-dated.md)

## Thinking

[rules/ai-thinking-dense.md](../rules/ai-thinking-dense.md): telegraphic reasoning, fewest tokens that still pick the action. Replies still follow Density.

## External systems (red line)

Writes to external systems (task trackers, issue and PR comments, chat, email, any third-party API that creates or updates content other people see):

1. Ask first: propose the exact target and full payload, wait for explicit approval
2. Disclose agency: state that the message is on behalf of the user, never imply the agent is the principal
3. One approval covers one write; ask again for each new external write unless the user pre-authorized that action in the same turn

Local-only work (repo files, local database) is out of scope; local git commits follow the repo's commit rules. External reads need no approval.

## Entry-point files

`CLAUDE.md`, `AGENTS.md` hold only:

1. Startup and shutdown sequence
2. Priority hierarchy and red lines
3. References to detailed rule files

Detailed rules live in dedicated files (`docs/`, `rules/`) loaded on demand. Entry points stay under ~50 lines.

## Checks

[rules/deterministic-checks.md](../rules/deterministic-checks.md): a script decides every check it implements. Run it. AI judges only what no script covers. Clean-code floor: [rules/clean-code.md](../rules/clean-code.md).

## Shell hygiene

- Quote paths that contain spaces: `"path/with spaces"`
- Prefer `rg` / `grep -r`, `find … -exec … +`, and dedicated tools over `xargs` pipelines (each `xargs` can trigger a permission prompt)
- One combined read-only command over many small ones; write and destructive commands are unaffected

## Delegation

- Exploratory searches: parallel cheaper subagents, one per area; the main agent decides and synthesizes
- Large plans: delegate CLI and MCP execution steps to subagents

## Teaching mode (off by default)

On only when the user asks to learn or be walked through:

- Explain the concept first; let the user attempt the command
- Correct a near miss in one line; give one hint when far off
- Off when the user says "just do it"
