# AI files: telegraphic

AI files = rules, skills, hooks, agent docs (`AGENTS.md`, `CLAUDE.md`), prompts, templates read by agents. Write telegraphic: max signal per token, still scannable by a human.

| Do | Don't |
|---|---|
| Tables, nested bullets, `key: value` | Prose paragraphs |
| Fragments; drop articles, filler, hedges | "In order to", "please note", "it is important" |
| One fact once; link instead of repeat | Restating a parent bullet or another file |
| Imperatives: "Run X", "Never Y" | Explaining why, unless it changes a decision |
| Symbols: `→ · ≤ ≥ ✓ ✗` | ASCII art, banners, emoji decoration |
| Abbrev only if standard (`PR`, `CI`, `env`) | Invented shorthand a reader must decode |

- Budget: skill body ≤ ~60 lines; rule ≤ ~40; one screen preferred
- Cut test: delete a line; if no agent decision changes, keep it deleted
- Not minified: keep headings, line breaks, real words. Readable cold by a human in one pass
- Scripts own the detail (`--help`); AI file names the script and when
