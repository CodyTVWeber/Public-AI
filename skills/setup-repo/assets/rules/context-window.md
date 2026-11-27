# Context window

Working context cap: 175000 tokens (175k). A user message, skill, or repo rule that names another cap wins for that work.

| When | Do |
|---|---|
| Under the cap | Continue. Drop stale tool output as you go |
| At or over the cap | Autocompact before the next large read, write, or tool call |
| Host reports no token count | Estimate. Compact at the cap anyway |

- Cap is the working maximum, including when the model window is larger
- Autocompact: run the host compact when one exists. Otherwise replace history with a short state and continue
- Keep: goal, constraints, decisions, open work, paths, latest error, and any named cap
- Drop: raw tool dumps, repeated file bodies, finished side paths, restated plans
- Never raise the cap to finish a task. Compact, then continue
- Count host context tokens, not one message
