#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"
new_tmp

tool="$here/../lint/check-skill-catalog.sh"
root="$TMPROOT/repo"

write_pack() {
  mkdir -p "$root/skills/setup-repo/assets" "$root/skills/alpha" "$root/skills/beta"
  printf '%s\n' '---' 'name: alpha' '---' '# Alpha' > "$root/skills/alpha/SKILL.md"
  printf '%s\n' '# Beta' > "$root/skills/beta/SKILL.md"
  cat > "$root/skills/setup-repo/assets/skills-manifest.json" <<'EOF'
{
  "core": ["alpha"],
  "support": [],
  "aliases": [],
  "design": ["beta"],
  "experimental": [],
  "other": []
}
EOF
  cat > "$root/skills/CATALOG.md" <<'EOF'
# Catalog

| Skill | Class | Does |
| --- | --- | --- |
| `alpha` | core | One job |
| `beta` | design | Other job |
EOF
}

write_pack
out="$("$tool" --root "$root" 2>&1)"; assert_rc "matching pack passes" 0 $?
assert_eq "matching pack is quiet" "" "$out"

printf '%s\n' '| `alpha` | core | One job |' > "$root/skills/CATALOG.md"
out="$("$tool" --root "$root" 2>&1)"; assert_rc "dropped name fails" 1 $?
assert_contains "names the dropped skill" "$out" "beta"

write_pack
jq '.design = ["beta", "beta"]' "$root/skills/setup-repo/assets/skills-manifest.json" > "$TMPROOT/manifest.json"
mv "$TMPROOT/manifest.json" "$root/skills/setup-repo/assets/skills-manifest.json"
out="$("$tool" --root "$root" 2>&1)"; assert_rc "duplicate manifest name fails" 1 $?
assert_contains "names the duplicate" "$out" "duplicate manifest: beta"

write_pack
mkdir -p "$root/skills/gamma"
printf '%s\n' '# Gamma' > "$root/skills/gamma/gamma.md"
ln -s gamma.md "$root/skills/gamma/SKILL.md"
out="$("$tool" --root "$root" 2>&1)"; assert_rc "unlisted symlink skill fails" 1 $?
assert_contains "names the symlink skill" "$out" "gamma"
jq '.other = ["gamma"]' "$root/skills/setup-repo/assets/skills-manifest.json" > "$TMPROOT/manifest.json"
mv "$TMPROOT/manifest.json" "$root/skills/setup-repo/assets/skills-manifest.json"
printf '\n| `gamma` | other | Linked |\n' >> "$root/skills/CATALOG.md"
out="$("$tool" --root "$root" 2>&1)"; assert_rc "listed symlink skill passes" 0 $?

"$tool" --help >/dev/null; assert_rc "help exits 0" 0 $?
"$tool" --root >/dev/null 2>&1; assert_rc "missing root is usage" 2 $?

finish
