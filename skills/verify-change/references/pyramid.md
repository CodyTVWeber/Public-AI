# Verification pyramid

Plan and align name the middle and top of the testing pyramid. Those rows are the contract. Unit tests are not in it.

| Layer | Means | Cases | Who writes it |
| --- | --- | --- | --- |
| `system` | UI, REST, or other in-system observable | happy and critical only, few | test implementer |
| `api` | Talks to the app; no external services | happy and critical only, few | test implementer |
| (script rows) | Same observables, run by a person or a shell recipe | happy and critical only, few | script implementer |
| unit | Internals | — | feature implementer, never this table |

Observable = what a person or an API caller sees: "user clicks Save and the row appears", "POST /items creates an item". The code under that can change; these rows should not.

Writer `test` → automated pyramid test. Writer `script` → plan-folder recipe. Feature implementer writes product code and unit tests only.

Caps (enforced by `scripts/check-pyramid.sh`): 4 system tests, 8 api tests, 6 scripts. Skip line when there is no runtime behavior: `No runtime change: pyramid skipped.`

Verify runs the rows. It does not invent them.
