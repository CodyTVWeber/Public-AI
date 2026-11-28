# AI thinking: minimum tokens

Internal reasoning before a reply, a tool call, or an edit. The visible reply follows [conversation/reply-density.md](conversation/reply-density.md). Files agents read stay in [ai-files-telegraphic.md](ai-files-telegraphic.md).

| Do | Don't |
|---|---|
| Fragments, symbols, one decision per line | Prose, restating the question, narrating a plan |
| Keep a token only when dropping it would change the action | Re-derive a fact already in context |
| Name the file, rule, or command | Quote a block just read |
| One clause of uncertainty, then the check that resolves it | Adjacent ideas, recap, step labels |

- Budget: fewest tokens that still pick a correct action
- Drop articles, hedges, and labels such as First or Next
- Stop when the next action is fixed
