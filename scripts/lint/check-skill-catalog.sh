#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-skill-catalog.sh [--root DIR]
Fails unless the manifest classes core, support, aliases, design, experimental,
and other partition every SKILL.md name, and skills/CATALOG.md has one row
"| name | class |" for that name.
Name: frontmatter name, else the skill directory basename.
Exit: 0 ok, 1 mismatch, 2 usage
EOF
}

root=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --root) root="${2:-}"; [ -n "$root" ] || { usage >&2; exit 2; }; shift 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || { usage >&2; exit 2; }
fi

CLASSES="core support aliases design experimental other"
manifest="$root/skills/setup-repo/assets/skills-manifest.json"
catalog="$root/skills/CATALOG.md"
bad=0

require_files() {
  [ -f "$manifest" ] || fail "missing $manifest"
  [ -f "$catalog" ] || fail "missing $catalog"
  [ "$bad" -eq 0 ]
}

skill_name() {
  local file="$1" found
  found="$(awk 'BEGIN{n=0} /^---$/{n++; next} n==1 && /^name:[[:space:]]/{sub(/^name:[[:space:]]*/,""); gsub(/["'\'' ]/,""); print; exit}' "$file")"
  if [ -n "$found" ]; then printf '%s\n' "$found"; else basename "$(dirname "$file")"; fi
}

list_skills() {
  find "$root/skills" \( -type f -o -type l \) -name SKILL.md | sort | while IFS= read -r file; do
    skill_name "$file"
  done
}

list_manifest() {
  local class
  for class in $CLASSES; do
    jq -r --arg c "$class" '(.[$c] // [])[]' "$manifest" | while IFS= read -r name; do
      [ -n "$name" ] && printf '%s\t%s\n' "$class" "$name"
    done
  done
}

report_dups() {
  local label="$1" file="$2" name
  while IFS= read -r name; do
    [ -n "$name" ] && fail "duplicate $label: $name"
  done < <(sort "$file" | uniq -d)
}

report_only() {
  local label="$1" left="$2" right="$3" name
  while IFS= read -r name; do
    [ -n "$name" ] && fail "$label: $name"
  done < <(comm -23 "$left" "$right")
}

class_of() {
  local name="$1" rows
  rows="$(awk -F'\t' -v n="$name" '$2==n {print $1}' "$work/manifest")"
  printf '%s\n' "$rows" | head -n 1
}

check_rows() {
  local name class hits
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    class="$(class_of "$name")"
    needle='| `'"$name"'` | '"$class"' |'
    hits="$(grep -cF "$needle" "$catalog" || true)"
    [ "$hits" -eq 1 ] || fail "catalog row for $name ($class): found $hits"
  done < "$work/skills"
}

check_extra_rows() {
  local name
  while IFS= read -r name; do
    grep -qxF "$name" "$work/skills" || fail "catalog names an unknown skill: $name"
  done < <(grep -oE '^\| `[a-z0-9-]+`' "$catalog" | sed -E 's/^\| `//; s/`$//')
}

fail() { printf 'check-skill-catalog: %s\n' "$1" >&2; bad=1; }

main() {
  require_files || exit 1
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  list_skills | sort > "$work/skills"
  list_manifest | sort > "$work/manifest"
  cut -f2 "$work/manifest" | sort > "$work/manifest-names"
  report_dups skill "$work/skills"
  report_dups manifest "$work/manifest-names"
  report_only "skill missing from manifest" "$work/skills" "$work/manifest-names"
  report_only "manifest name has no SKILL.md" "$work/manifest-names" "$work/skills"
  check_rows
  check_extra_rows
  [ "$bad" -eq 0 ]
}

main
