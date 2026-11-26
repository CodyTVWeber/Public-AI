#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/fixtures.sh"
new_tmp
unset PUBLIC_AI_DIR

tool="$TMPROOT/tool"; mkdir -p "$tool"
cp -R "$here/../.." "$tool/setup-repo"
rm -rf "$tool/setup-repo/scripts/tests"
git -C "$tool" init -q; git -C "$tool" config user.name t; git -C "$tool" config user.email t.example
git -C "$tool" add -- .; git -C "$tool" commit -qm tool
sha="$(git -C "$tool" rev-parse HEAD)"
BS="$tool/setup-repo/scripts/bootstrap.sh"; VR="$tool/setup-repo/scripts/verify-repo.sh"
rules="$tool/setup-repo/assets/rules"
status_of() { jq -r --arg id "$2" '.checks[] | select(.id == $id) | .status' <<<"$1"; }
drift_of() { jq -r --arg p "$2" '[.drift[] | select(.path == $p) | .status] | join(",")' <<<"$1"; }
hash_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
apply() { local t="$1"; shift; "$BS" "$t" --apply --yes --skills none "$@" 2>/dev/null; }

a="$TMPROOT/target"; go_bare "$a"
apply "$a" >/dev/null
record="$a/.claude/ai-guardrails.json"
assert_eq "record stamps the source commit" "$sha" "$(jq -r .source_sha "$record")"
assert_eq "record hashes each installed file" "$(hash_of "$a/.claude/rules/clean-code.md")" "$(jq -r '.files[".claude/rules/clean-code.md"].hash' "$record")"
assert_eq "record covers scripts too" "true" "$(jq -r '.files | has("scripts/clean-code/post-git-check.sh")' "$record")"
json="$("$VR" "$a" 2>/dev/null)"; assert_rc "fresh install verifies" 0 $?
assert_eq "no drift" "[]" "$(jq -c .drift <<<"$json")"
assert_eq "drift check passes" "pass" "$(status_of "$json" drift)"

printf 'upstream change\n' >> "$rules/clean-code.md"
printf 'my edit\n' >> "$a/.claude/rules/ban-comments.md"
rm "$a/.claude/rules/small-mrs.md"
json="$("$VR" "$a" 2>/dev/null)"; assert_rc "a missing file fails verify" 1 $?
assert_eq "changed-upstream reported" "changed-upstream" "$(drift_of "$json" .claude/rules/clean-code.md)"
assert_eq "modified-locally reported" "modified-locally" "$(drift_of "$json" .claude/rules/ban-comments.md)"
assert_eq "missing reported" "missing" "$(drift_of "$json" .claude/rules/small-mrs.md)"
assert_eq "drift check fails on missing" "fail" "$(status_of "$json" drift)"

mine="$(cat "$a/.claude/rules/ban-comments.md")"
out="$(apply "$a")"
assert_eq "plain apply keeps the upstream-changed file" "false" "$(cmp -s "$rules/clean-code.md" "$a/.claude/rules/clean-code.md" && echo true || echo false)"
assert_contains "plain apply points at --upgrade" "$(jq -r '.steps[] | select(.path == ".claude/rules/clean-code.md") | .reason' <<<"$out")" "--upgrade"
[ -e "$a/.claude/rules/small-mrs.md" ] && ok || bad "missing file is recreated"

out="$(apply "$a" --upgrade)"; assert_rc "upgrade ok" 0 $?
assert_eq "upgrade takes the changed-upstream file" "true" "$(cmp -s "$rules/clean-code.md" "$a/.claude/rules/clean-code.md" && echo true || echo false)"
assert_eq "upgrade leaves the local edit alone" "$mine" "$(cat "$a/.claude/rules/ban-comments.md")"
assert_contains "upgrade reports the kept file" "$(jq -r '.notes | join(" ")' <<<"$out")" ".claude/rules/ban-comments.md"
assert_eq "kept file is a manual step" "manual" "$(jq -r '.steps[] | select(.path == ".claude/rules/ban-comments.md") | .action' <<<"$out")"
json="$("$VR" "$a" 2>/dev/null)"; assert_rc "verify after upgrade" 0 $?
assert_eq "only the local edit still drifts" ".claude/rules/ban-comments.md modified-locally" "$(jq -r '[.drift[] | .path + " " + .status] | join(",")' <<<"$json")"
assert_eq "record hash follows the upgrade" "$(hash_of "$rules/clean-code.md")" "$(jq -r '.files[".claude/rules/clean-code.md"].hash' "$record")"
assert_eq "drift check warns" "warn" "$(status_of "$json" drift)"

out="$(apply "$a" --upgrade)"
assert_eq "second upgrade writes nothing" "" "$(jq -r '[.steps[] | select(.action == "create" or .action == "merge") | .id] | join(" ")' <<<"$out")"

apply "$a" --upgrade --force >/dev/null
assert_eq "force overwrites the local edit" "true" "$(cmp -s "$rules/ban-comments.md" "$a/.claude/rules/ban-comments.md" && echo true || echo false)"
assert_eq "no drift after force" "[]" "$(jq -c .drift <<<"$("$VR" "$a" 2>/dev/null)")"

printf 'second upstream change\n' >> "$tool/setup-repo/assets/scripts/check-mr-size.sh"
printf 'edit\n' >> "$a/scripts/clean-code/check-mr-size.sh"
json="$("$VR" "$a" 2>/dev/null)"
assert_eq "local edit wins over upstream change" "modified-locally" "$(drift_of "$json" scripts/clean-code/check-mr-size.sh)"

b="$TMPROOT/local"; go_bare "$b"
apply "$b" --local >/dev/null
lrec="$b/.git/info/local-guardrails.json"
assert_eq "local record stamps the commit" "$sha" "$(jq -r .source_sha "$lrec")"
printf 'more\n' >> "$rules/small-mrs.md"
assert_eq "local drift reported" "changed-upstream" "$(drift_of "$("$VR" "$b" 2>/dev/null)" .claude/rules/small-mrs.md)"
apply "$b" --local --upgrade >/dev/null
assert_eq "local upgrade applies" "true" "$(cmp -s "$rules/small-mrs.md" "$b/.claude/rules/small-mrs.md" && echo true || echo false)"
assert_eq "local tree stays clean" "" "$(git -C "$b" status --porcelain --untracked-files=all)"

n="$TMPROOT/nogit"; mkdir -p "$n/setup-repo"; cp -R "$tool/setup-repo/." "$n/setup-repo/"
c="$TMPROOT/unknown"; go_bare "$c"
"$n/setup-repo/scripts/bootstrap.sh" "$c" --apply --yes --skills none >/dev/null 2>&1
assert_eq "no source commit records unknown" "unknown" "$(jq -r .source_sha "$c/.claude/ai-guardrails.json")"

pub="$TMPROOT/pub"; real="$here/../../../.."
mkdir -p "$pub/skills/ai-risk" "$pub/scripts/guard" "$pub/skills/setup-repo"
cp "$real/scripts/check-privacy.sh" "$real/scripts/install-hooks.sh" "$pub/scripts/"
cp "$real/scripts/guard/git-approval-guard.sh" "$real/scripts/guard/research-ref.sh" "$pub/scripts/guard/"
w="$pub/skills/setup-repo"; cp -R "$tool/setup-repo/." "$w/"
mv "$w/scripts/install.sh" "$w/scripts/install.real"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/install.log"\nexec "$(dirname "$0")/install.real" "$@"\n' "$TMPROOT" > "$w/scripts/install.sh"
chmod +x "$w/scripts/install.sh"
d="$TMPROOT/one-writer"; go_bare "$d"; mkdir -p "$d/scripts"
"$w/scripts/bootstrap.sh" "$d" --apply --yes --skills none --with approval-gate,research-ref >/dev/null 2>&1
log="$(cat "$TMPROOT/install.log")"
assert_contains "core files go through install.sh" "$log" "--no-claude-hook"
assert_contains "add-on files go through install.sh --copy" "$log" "--copy"
assert_contains "the guard copy names its destination" "$log" "scripts/guard/git-approval-guard.sh"
[ -x "$d/scripts/guard/research-ref.sh" ] && ok || bad "add-on copy is executable"
assert_eq "setuplib holds no file-copy code" "" "$(grep -rlE 'shutil[.]copy|copyfile|filecmp' "$here/../lib/setuplib" || true)"
r="$TMPROOT/removed"; go_bare "$r"
apply "$r" >/dev/null
rm "$rules/research-latest-main.md"
json="$("$VR" "$r" 2>/dev/null)"
assert_eq "source file deleted upstream is reported" "removed-upstream" "$(drift_of "$json" .claude/rules/research-latest-main.md)"
assert_eq "removed-upstream warns, never fails" "warn" "$(status_of "$json" drift)"
rm "$r/.claude/rules/research-latest-main.md"
apply "$r" >/dev/null
assert_eq "re-apply prunes entries whose file is gone" "false" "$(jq -r '.files | has(".claude/rules/research-latest-main.md")' "$r/.claude/ai-guardrails.json")"
finish
