#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/fixtures.sh"
new_tmp
unset PUBLIC_AI_DIR

clone="$TMPROOT/clone"; mkdir -p "$clone"; clone="$(cd "$clone" && pwd -P)"
CORE="write-plan align implement review watch plan-implement-review-watch plan-implement-review verify-change monitor review-plan review-logic review-non-happy-logic review-tests review-security review-data review-ui review-dependencies review-infra review-concurrency review-code-quality review-proof"
ALIASES="pirw ir irw rw pi pir review-watch implement-review implement-review-watch plan-implement plan verify apir apirw apirvw apirwm pirvw code-review"
fake_clone "$clone" $CORE $ALIASES check-work setup-repo
links_of() { jq -r '[.steps[] | select(.id == "skills") | .reason] | join(" ")' <<<"$1"; }
linked() { (cd "$1/.claude/skills" 2>/dev/null && ls | tr '\n' ' ' | sed 's/ $//'); }
sorted() { printf '%s\n' $1 | sort | tr '\n' ' ' | sed 's/ $//'; }
apply() { local t="$1"; shift; "$BOOTSTRAP" "$t" --apply --yes --skills-from "$clone" "$@" 2>/dev/null; }

a="$TMPROOT/default"; go_bare "$a"
apply "$a" >/dev/null
assert_eq "default set is the 6 core and 15 support skills" "$(sorted "$CORE")" "$(linked "$a")"

b="$TMPROOT/aliases"; go_bare "$b"
apply "$b" --skills core+aliases >/dev/null
assert_eq "core+aliases adds the 18 aliases" "$(sorted "$CORE $ALIASES")" "$(linked "$b")"

c="$TMPROOT/all"; go_bare "$c"
apply "$c" --skills all >/dev/null
assert_eq "all links every skill with a SKILL.md" "$(sorted "$CORE $ALIASES check-work setup-repo")" "$(linked "$c")"

d="$TMPROOT/none"; go_bare "$d"
json="$(apply "$d" --skills none)"
assert_eq "none has no skills step" "" "$(step_action "$json" skills)"
[ -d "$d/.claude/skills" ] && bad "none links nothing" || ok

e="$TMPROOT/list"; go_bare "$e"
apply "$e" --skills review,check-work >/dev/null
assert_eq "explicit list links exactly those" "check-work review" "$(linked "$e")"
"$BOOTSTRAP" "$e" --skills 'Bad Name' >/dev/null 2>&1; assert_rc "invalid set is usage" 2 $?

x="$TMPROOT/excludes"; go_bare "$x"
mkdir -p "$x/.claude/skills/team-skill"; printf 'x\n' > "$x/.claude/skills/team-skill/SKILL.md"
apply "$x" >/dev/null
assert_contains "team skill stays visible to git" "$(git -C "$x" status --porcelain --untracked-files=all)" ".claude/skills/team-skill/SKILL.md"
assert_not_contains "created links are hidden" "$(git -C "$x" status --porcelain --untracked-files=all)" ".claude/skills/review"
assert_eq "one entry per link" "21" "$(grep -c '^\.claude/skills/' "$x/.git/info/exclude")"
before="$(cat "$x/.git/info/exclude")"
apply "$x" >/dev/null
assert_eq "exclude entries are idempotent" "$before" "$(cat "$x/.git/info/exclude")"
rm "$x/.claude/skills/watch"
apply "$x" --skills review >/dev/null
assert_not_contains "entry of a removed link is cleaned" "$(cat "$x/.git/info/exclude")" ".claude/skills/watch"
assert_contains "entry of a surviving link stays" "$(cat "$x/.git/info/exclude")" ".claude/skills/implement"
printf '# mine\n.claude/skills/\n' >> "$x/.git/info/exclude"
apply "$x" >/dev/null
assert_not_contains "legacy directory entry is dropped" "$(grep -x '.claude/skills/' "$x/.git/info/exclude")" ".claude/skills/"
assert_contains "user lines kept" "$(cat "$x/.git/info/exclude")" "# mine"

n="$TMPROOT/nosource"; go_bare "$n"
fakehome="$TMPROOT/fakehome"; legacy="$fakehome/code/Public-AI"
mkdir -p "$legacy"; cp -R "$clone/skills" "$legacy/skills"
json="$(HOME="$fakehome" "$BOOTSTRAP" "$n" --plan 2>/dev/null)"
assert_eq "no source is a manual skills step" "manual" "$(step_action "$json" skills)"
assert_contains "step says how to set the source" "$(links_of "$json")" "PUBLIC_AI_DIR"
assert_contains "step names --skills-from" "$(links_of "$json")" "--skills-from"
json="$(HOME="$fakehome" PUBLIC_AI_DIR="$clone" "$BOOTSTRAP" "$n" --plan 2>/dev/null)"
assert_eq "PUBLIC_AI_DIR supplies the source" "create" "$(step_action "$json" skills)"
HOME="$fakehome" "$LINK" "$n" >/dev/null 2>&1; assert_rc "link-skills has no home default" 3 $?
HOME="$fakehome" PUBLIC_AI_DIR="$clone" "$LINK" "$n" >/dev/null 2>&1; assert_rc "link-skills reads PUBLIC_AI_DIR" 0 $?

det="$(HOME="$fakehome" "$DETECT" "$n" 2>/dev/null)"
assert_eq "detect recommends no skills without a source" "--skills none" "$(jq -r '.recommend.flags[] | select(.flag | startswith("--skills")) | .flag' <<<"$det")"
det="$(HOME="$fakehome" PUBLIC_AI_DIR="$clone" "$DETECT" "$n" 2>/dev/null)"
assert_eq "detect recommends core with a source" "--skills core" "$(jq -r '.recommend.flags[] | select(.flag | startswith("--skills")) | .flag' <<<"$det")"
assert_contains "recommendation names the aliases opt-in" "$(jq -r '.recommend.flags[] | select(.flag | startswith("--skills")) | .reason' <<<"$det")" "core+aliases"
finish
