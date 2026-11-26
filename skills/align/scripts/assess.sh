#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: assess.sh [--file F | TEXT...]   (-h|--help)

Scores a task or document with fixed heuristics. Stdout JSON:
  {size, vagueness, ui, suggest_align, reasons[], signals{}}

Signals
  vague      distinct count of vague words: etc, maybe, somehow, improve, better, as needed,
             TBD, "and so on", "if possible", ...
  acceptance 1 when the text names acceptance criteria, a definition of done, or "done when"
  areas      distinct systems (api, database, auth, ...); scoring adds distinct file names
  joins      count of " and " / "&" / ";" joining deliverables
  cross_repo 1 when it names several repos, services or teams
  words      word count

size points      words >= 60: +1, >= 150: +2 | areas >= 3: +1, >= 5: +2 | joins >= 2: +1, >= 4: +2
                 cross_repo: +2 | bullet lines >= 5: +1
                 points >= 4 large, >= 2 medium, else small
vagueness points vague hits (max 3) | no acceptance and size not small: +1
                 under 6 words and no file named: +1
                 points >= 3 high, == 2 medium, else low
ui               1 strong word (screen, page, modal, component, layout, Figma, mobile, ...)
                 or 2 weak words (style, copy, design)
suggest_align    (size large and vagueness medium|high) or vagueness high

Exit: 0 ok, 2 usage or empty input
USAGE
}

VAGUE='etc|maybe|somehow|improve|improves|improved|improving|better|as needed|tbd|tbc|and so on|and stuff|if possible|where possible|kind of|sort of|something like|nice to have|user-friendly|intuitive|robust|flexible|various|clean up|cleanup|probably|figure out'
ACCEPT='acceptance|definition of done|done when|criteria|ac-[0-9]+|given .* then|expected result'
AREAS='api|database|db|frontend|backend|service|auth|billing|queue|cache|search|email|notification|notifications|report|reports|migration|pipeline|cli|worker|scheduler|webhook|dashboard|permissions|logging|analytics|storage|payments|cron|sync'
FILES='[A-Za-z0-9_./-]+\.(ts|tsx|js|jsx|py|kt|java|go|rb|sh|md|json|ya?ml|sql|css|html|swift|rs)'
CROSS='repos|repositories|cross-repo|other service|other services|upstream|downstream|monorepo|across services|across teams|multiple services'
UI_STRONG='screen|screens|page|pages|modal|dialog|component|components|layout|figma|mobile|button|css|ui|ux|responsive|tooltip|dropdown|sidebar|navbar'
UI_WEAK='style|styles|styling|copy|design'

die_usage() { usage >&2; exit 2; }

read_text() {
  if [[ "${1:-}" == "--file" ]]; then
    [[ $# -eq 2 && -f "$2" ]] || die_usage
    cat "$2"
  else
    printf '%s' "$*"
  fi
}

count_distinct() { grep -oiwE "$1" <<<"$2" | tr '[:upper:]' '[:lower:]' | sort -u | wc -l | tr -d ' ' || true; }
count_all() { grep -oiwE "$1" <<<"$2" | wc -l | tr -d ' ' || true; }
count_files() { grep -oE "$FILES" <<<"$1" | sort -u | wc -l | tr -d ' ' || true; }
count_bullets() { grep -cE '^[[:space:]]*([-*]|[0-9]+\.) ' <<<"$1" || true; }
count_joins() { grep -oiE ' and |&|;' <<<"$1" | wc -l | tr -d ' ' || true; }

signals() {
  local text="$1" accept cross
  accept="$(count_all "$ACCEPT" "$text")"
  cross="$(count_all "$CROSS" "$text")"
  jq -nc \
    --argjson words "$(wc -w <<<"$text" | tr -d ' ')" \
    --argjson vague "$(count_distinct "$VAGUE" "$text")" \
    --argjson acceptance "$(( accept > 0 ? 1 : 0 ))" \
    --argjson files "$(count_files "$text")" \
    --argjson areas "$(count_distinct "$AREAS" "$text")" \
    --argjson joins "$(count_joins "$text")" \
    --argjson cross_repo "$(( cross > 0 ? 1 : 0 ))" \
    --argjson bullets "$(count_bullets "$text")" \
    --argjson ui_strong "$(count_distinct "$UI_STRONG" "$text")" \
    --argjson ui_weak "$(count_distinct "$UI_WEAK" "$text")" \
    '$ARGS.named'
}

read -r -d '' SCORE <<'JQ' || true
def ge($n; $t): if $n >= $t then 1 else 0 end;
(.areas + .files) as $areas
| (ge(.words;60) + ge(.words;150) + ge($areas;3) + ge($areas;5) + ge(.joins;2) + ge(.joins;4)
   + (.cross_repo * 2) + ge(.bullets;5)) as $sp
| (if $sp >= 4 then "large" elif $sp >= 2 then "medium" else "small" end) as $size
| ((if .vague > 3 then 3 else .vague end)
   + (if $size != "small" and .acceptance == 0 then 1 else 0 end)
   + (if .words < 6 and .files == 0 then 1 else 0 end)) as $vp
| (if $vp >= 3 then "high" elif $vp == 2 then "medium" else "low" end) as $vagueness
| (.ui_strong >= 1 or .ui_weak >= 2) as $ui
| {size: $size, vagueness: $vagueness, ui: $ui,
   suggest_align: (($size == "large" and $vagueness != "low") or $vagueness == "high"),
   reasons: ([
     (if .vague > 0 then "\(.vague) vague phrases" else empty end),
     (if $size != "small" and .acceptance == 0 then "no acceptance criteria or definition of done" else empty end),
     (if $areas >= 3 then "\($areas) areas or files named" else empty end),
     (if .joins >= 2 then "\(.joins) joined deliverables" else empty end),
     (if .cross_repo == 1 then "spans repos or services" else empty end),
     (if $ui then "UI signals" else empty end)
   ]),
   signals: .}
JQ

main() {
  case "${1:-}" in -h|--help) usage; exit 0 ;; esac
  local text
  text="$(read_text "$@")"
  [[ -n "${text//[[:space:]]/}" ]] || die_usage
  signals "$text" | jq "$SCORE"
}

main "$@"
