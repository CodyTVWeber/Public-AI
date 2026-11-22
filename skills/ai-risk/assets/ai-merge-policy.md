# AI merge policy

Merge policy: conservative

This line decides who may merge an agent's pull request. Options: `conservative` (every change
needs another person's approval), `balanced` (approval scales with the change's risk tier),
`yolo` (the agent merges everything). Definitions and the per-tier rules: `merge-policy.md`.

`conservative` is the default, and a missing file means the same thing. Changing this line is its
own pull request, approved by the designated owner. Do not change it inside a feature pull
request.

<!-- balanced only: add the next line to let an agent merge a low-tier pull request unattended.
Auto-merge low: on -->
