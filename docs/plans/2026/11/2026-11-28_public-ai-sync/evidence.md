# Evidence index

Date: 2026-11-28
Plan: ../2026-11-28_public-ai-sync.md
PR: https://github.com/CodyTVWeber/Public-AI/pull/23
Kinds: script

## Proof

| Claim | Kind | Where |
| --- | --- | --- |
| `npm install` in test-consumer fills `.public-ai` | script | `out/consumer.txt` |
| Failed fetch and empty source leave the previous target | script | `out/unit.txt` |
| Second sync replaces the tree | script | `out/consumer.txt` |
| Bump dry-run skips publish without a token | script | `out/bump.txt` |

## Scripts

- `verify.sh` — unit tests, dummy-consumer install, bump `--dry-run`

## Outputs

Tiny stdout in `out/`.
