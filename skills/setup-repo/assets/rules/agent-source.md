# One source for agent rules

Edit `AGENTS.md` and the `rules/` it links. That file is the generic source. A vendor file only redirects there.

| File | Role |
| --- | --- |
| `AGENTS.md` | Generic source. Put every rule change here |
| `CLAUDE.md` | Claude redirect |
| `GEMINI.md` | Gemini redirect |

- Redirect body: `@AGENTS.md`. Optional one line: do not edit; rules live in `AGENTS.md`
- A product that already reads `AGENTS.md` (Cursor, Codex, Copilot) gets no second file
- A new product that only reads its own filename: add that filename as a redirect. Do not copy rules into it
- Never edit a redirect. A redirect that holds real rules is a mistake: move the rules into `AGENTS.md`, leave the redirect
