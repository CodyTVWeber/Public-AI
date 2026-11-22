# AI auto-merge

AI auto-merge: off

This line is the switch for agents merging with no person approving that pull request.

`off` is the default. Missing file means the same thing. An agent merges unattended only when
this line reads `AI auto-merge: on`, or the team or org has a written allow that names this repo.

Turning it on is its own change, reviewed by the owner. Do not flip the line inside a feature
pull request.

When it is on, only a low pull request qualifies, and only after the checks in the auto-merge
rule. Medium and high still wait for a person.
