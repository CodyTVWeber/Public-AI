# Deterministic checks

A script's result is the decision. Run the script. Do not re-judge a finding it emitted, and do not eyeball a check it implements.

| Check | Script |
|---|---|
| File size, function order, length, params, nesting, guard wraps, comments, magic numbers, mutation, boolean flags, duplicate strings, inline try/catch, layer folders | `code-quality-check.sh` |
| Docs: current state or dated snapshot | `lint-docs.sh` |
| MR size | `check-mr-size.sh` |
| Script language | `check-languages.sh` |
| Copy drift | `check-copies.sh` |

- Repo-local `lint-clean-code.sh BASE` runs the comment and banner grep, then the same `code-quality-check.sh` rules
- Thresholds and skips: `code-quality-check.sh -h`. `CC_SKIP=1` and `CLEAN_CODE_SKIP=1` skip a run and say so; fix the code instead
- AI judges only what no script covers: one definition per business rule, names that match docs, which extraction is the right boundary ([clean-code.md](clean-code.md))
- Review reads the script output first ([review-code-quality](../skills/review-code-quality/review-code-quality.md))
