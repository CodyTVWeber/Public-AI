#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-pr-body.sh <body-file|-> [-h|--help]

Validates a pull request body against assets/pr-body.md:
  - headers: What changed, Risk, Review guide, Build, Proof, Try it (Rollback when tier is high)
  - Risk starts with exactly one tier: low | medium | high, and has a "Merge policy: <profile>"
    line (conservative | balanced | yolo)
  - Review guide labels: Size, Start here, Look hard, Skim, Not in this change, Stack,
    Decisions to check
  - Build labels: Command, CI, Result
  - no leftover `<placeholder>` text or template sample text
  - Try it: numbered step 1, at most 2 numbered steps (point, do not walk through)
  - at most 12 non-blank lines before "## Proof" (warns above 8)
Prints JSON: {"ok","tier","lines_before_proof","missing":[...],"warnings":[...]}
Exit: 0 ok, 1 failed (missing list in JSON), 2 usage
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac
src="$1"
if [ "$src" = "-" ]; then
  body="$(cat)"
elif [ -f "$src" ]; then
  body="$(cat "$src")"
else
  echo "check-pr-body: no such file: $src" >&2
  exit 2
fi

missing=()
warnings=()

section() {
  printf '%s\n' "$body" | awk -v h="## $1" '
    /^```/ { fence = !fence }
    !fence && $0 == h { on = 1; next }
    !fence && /^## / { on = 0 }
    on { print }
  '
}
has_header() { printf '%s\n' "$body" | grep -Eq "^## $1[[:space:]]*\$"; }

for h in "What changed" "Risk" "Review guide" "Build" "Proof" "Try it"; do
  has_header "$h" || missing+=("header: ## $h")
done

tier=""
if has_header "Risk"; then
  first="$(section Risk | sed -n '/[^[:space:]]/{p;q;}')"
  if [[ "$first" == *low*medium*high* ]]; then
    missing+=("risk tier: pick one of low, medium, high")
  elif [[ "$first" =~ ^[[:space:]]*[\`*]*(low|medium|high)([^[:alnum:]]|$) ]]; then
    tier="${BASH_REMATCH[1]}"
  else
    missing+=("risk tier: Risk must start with low, medium or high")
  fi
  if ! section Risk | grep -Eiq 'Merge policy:[[:space:]]*`?(conservative|balanced|yolo)`?([^[:alnum:]]|$)'; then
    missing+=("Risk: 'Merge policy: <conservative|balanced|yolo>' line")
  fi
fi

if has_header "Review guide"; then
  guide="$(section "Review guide")"
  for label in "Size" "Start here" "Look hard" "Skim" "Not in this change" "Stack" "Decisions to check"; do
    printf '%s\n' "$guide" | grep -Fq "**$label:**" || missing+=("Review guide label: **$label:**")
  done
fi

if has_header "Build"; then
  build="$(section Build)"
  for label in "Command" "CI" "Result"; do
    printf '%s\n' "$build" | grep -Eq "^[[:space:]]*[-*][[:space:]]+$label:[[:space:]]*[^[:space:]]" || missing+=("Build label: $label:")
  done
fi

if has_header "Try it"; then
  try="$(section "Try it")"
  printf '%s\n' "$try" | grep -Eq '^[[:space:]]*1\.[[:space:]]+[^[:space:]]' || missing+=("Try it: numbered step 1.")
  steps="$(printf '%s\n' "$try" | grep -Ec '^[[:space:]]*[0-9]+\.' || true)"
  if [ "$steps" -gt 2 ]; then
    missing+=("Try it: at most 2 steps (got $steps); point at the scenario")
  fi
fi

if has_header "Proof"; then
  rows="$(section Proof | grep -Ec '^\|' || true)"
  [ "$rows" -ge 3 ] || missing+=("Proof: at least one table row under the header")
fi

if [ "$tier" = high ]; then
  has_header "Rollback" || missing+=("header: ## Rollback (required for high tier)")
  if has_header "Rollback"; then
    rb="$(section Rollback)"
    printf '%s\n' "$rb" | grep -q '[^[:space:]]' || missing+=("Rollback: empty")
    printf '%s\n' "$rb" | grep -Fq 'this section is required' && missing+=("Rollback: still the template text")
  fi
fi

stripped="$(printf '%s\n' "$body" | awk '/^```/ { fence = !fence; next } !fence { print }')"
while IFS= read -r ph; do
  [ -n "$ph" ] && missing+=("leftover placeholder: $ph")
done < <(printf '%s\n' "$stripped" | grep -Eo '`<[^`>]+>`' | sort -u)
printf '%s\n' "$body" | grep -Fq 'replace with the real call' && missing+=("leftover template sample: 'replace with the real call'")
printf '%s\n' "$body" | grep -Fq 'Api->>Db: example read' && missing+=("leftover template sample: example mermaid diagram")
printf '%s\n' "$body" | grep -Fq "One or two sentences. Name the behavior" && missing+=("leftover template text in What changed")

before="$(printf '%s\n' "$body" | awk '/^## Proof[[:space:]]*$/ { exit } NF { n++ } END { print n + 0 }')"
if [ "$before" -gt 12 ]; then
  missing+=("length: $before non-blank lines before ## Proof (limit about 8, hard 12)")
elif [ "$before" -gt 8 ]; then
  warnings+=("length: $before non-blank lines before ## Proof (target 8)")
fi

ok=true
[ "${#missing[@]}" -eq 0 ] || ok=false
to_json() { if [ "$#" -eq 0 ]; then echo '[]'; else printf '%s\n' "$@" | jq -Rn '[inputs]'; fi; }
jq -nc --argjson ok "$ok" --arg tier "$tier" --argjson n "$before" \
  --argjson missing "$(to_json "${missing[@]+"${missing[@]}"}")" \
  --argjson warnings "$(to_json "${warnings[@]+"${warnings[@]}"}")" \
  '{ok:$ok,tier:$tier,lines_before_proof:$n,missing:$missing,warnings:$warnings}'
[ "$ok" = true ] || exit 1
exit 0
