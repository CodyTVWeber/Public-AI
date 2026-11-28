# Evidence index

Date: 2026-11-28
Plan: ../2026-11-28_verify-phase.md
PR: https://github.com/CodyTVWeber/Public-AI/pull/18
Kinds: script

## Proof

| Claim | Kind | Where |
| --- | --- | --- |
| `pir` and `apir` insert verify after review | script | `out/pir.json`, `out/apir.json` |
| Plan folder gate accepts this recipe | script | `out/evidence-dir.json` |
| Empty kinds is a valid no-evidence pick | script | `check-evidence-dir` and `proof-check` tests |
| Verify can start 3 more implement/review rounds | script | `out/verdict-fix.json`, `out/verdict-hand.json` |

## Scripts

- `verify.sh` — runs `pir-args.sh`, `verdict.sh --phase verify`, `plan-dir.sh`, and `check-evidence-dir.sh` on this folder

## Outputs

Tiny stdout in `out/`. Images and video are not part of this change.
