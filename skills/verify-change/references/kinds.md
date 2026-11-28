# Evidence kinds

Menu. Pick the rows that prove this solution. Skip the rest.

| Kind | Use when | On the PR | Next to the plan |
| --- | --- | --- | --- |
| `image` | how a screen looks | before and after images | link in `evidence.md` |
| `video` | click, type, motion, sequence | short video | link |
| `curl` | backend call | curl, HTTP file, status, response fragment | script may issue the call; tiny stdout |
| `query` | database shape or row | read-only SQL and the result; which database | `.sql` and/or a script; tiny result |
| `log` | trace or correlation | log line | snippet |
| `diagram` | deep or wide path | mermaid of the changed hop | in `evidence.md` or the PR |
| `script` | anything a command can show | paste stdout; Try it is "run this script" | the `.sh` |
| `build` | a check command still runs | check command, CI link, one green line | — |
| _(empty)_ | docs, comments, rename, formatting; no runtime behavior | **no behavior change** line; no screenshots or scripts | `kinds: []` and a `reason`; no `.sh` |

Empty `kinds` is a pick, not a miss. Do not invent evidence. A still image is not proof of a behavior. Backend or database that a person reaches through a screen also needs that screen's video.

Fake or local data only. No production rows, secrets, or real personal data.
