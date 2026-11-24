# discover

Leader and scouts. The leader splits a target area into slices and spawns many cheap scout subagents to search them in parallel. Scouts return evidence in a fixed format; the leader verifies the key findings and synthesizes one answer.

Install: copy or symlink this folder into the agent's skills directory (user-level, or a project's `.claude/skills/`).

Use: `/discover <topic or question> [in <targets>]`

| Target | How scouts read it |
|---|---|
| Git repo | `origin/<default-branch>` after a fetch; never the working tree |
| Computer | Named roots only; secrets and bulk locations skipped |
| Web | Given URLs, read-only |
| Git forge | Optional, minimal: one scout, at most 5 read-only queries; never posts or changes state |
