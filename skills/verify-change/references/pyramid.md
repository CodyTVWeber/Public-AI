# Verification pyramid

Plan and align name the **top** of the testing pyramid (`system` and `api`). Those rows are ATDD: test-first from outside the app (UI, API, contracts). They verify observable behavior. Implementation under them may change; these tests should not. Unit tests and other inner workings stay with the feature implementer.

| Layer | Means | Cases | Who writes it |
| --- | --- | --- | --- |
| `system` | UI, REST, or other in-system observable | happy and critical only, few | ATDD implementer |
| `api` | Talks to the app; no external services | happy and critical only, few | ATDD implementer |
| (script rows) | Same observables, run by a person or a shell recipe | happy and critical only, few | script implementer |
| unit | Internals | — | feature implementer, never this table |

Observable = what a person or an API caller sees: "user clicks Save and the row appears", "POST /items creates an item".

Writer `atdd` → automated ATDD at the top of the pyramid. Writer `script` → plan-folder recipe. Feature implementer writes product code and unit tests only.

Caps (enforced by `scripts/check-pyramid.sh`): 4 system tests, 8 api tests, 6 scripts. Skip line when there is no runtime behavior: `No runtime change: pyramid skipped.`

Verify runs the rows. It does not invent them.
