# Context reuse (experimental)

Session memory for agents. Opt-in. Not a `rules/` floor. `setup-repo` does not copy it. `link-skills.sh --skills all` does not link it.

| File | Kind | Role |
|---|---|---|
| [context-reuse.md](context-reuse.md) | Current | Protocol |
| [STATE.md](STATE.md) | Current | Living high-level state |
| [summaries/](summaries/) | Dated | Session records |

Install by hand: `ln -sfn <path-to-this-repo>/skills/experimental/context-reuse ~/.agents/skills/context-reuse`

A skill moves to `skills/<name>/` when it joins the default set.
