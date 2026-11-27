Date: 2026-11-27
Supersedes: 2026-11-27-context-reuse.md

As of 2026-11-27 context reuse is an experimental skill, not a `rules/` floor.

## Goal

Keep the protocol available while it is unclear how it affects the rest of the repo.

## Decisions

- Home: `skills/experimental/context-reuse/`
- Not listed in `rules/README.md`. `setup-repo` does not copy it
- `AGENTS.md` points at the experiment as opt-in, not a session-start floor
- Living state and summaries live in this skill folder
- Dated docs stay immutable; this file records the change of home

## Open items

- Whether this skill joins the default set
- Fill summaries as sessions finish

## Facts and locations

- Protocol: `skills/experimental/context-reuse/context-reuse.md`
- State: `skills/experimental/context-reuse/STATE.md`
- Summaries: `skills/experimental/context-reuse/summaries/`

## Related

- `skills/experimental/README.md`
- `rules/docs-current-or-dated.md`
