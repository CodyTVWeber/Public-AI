# AI merge policy

Merge policy: conservative

Decides who may merge an agent's PR. Options:

- `conservative`: every change needs another person's approval; high tier normally gets two
- `balanced`: approval scales with risk tier
- `yolo`: agent merges everything

Definitions and per-tier rules: `merge-policy.md`.

- `conservative` is default; missing file = same
- Changing this line = own PR, approved by designated owner. Never inside a feature PR

<!-- balanced only: add next line to let agent merge low-tier PR unattended.
Auto-merge low: on -->
