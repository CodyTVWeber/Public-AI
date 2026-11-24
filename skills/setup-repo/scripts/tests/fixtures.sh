here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../../../../scripts/tests/lib.sh"
SCRIPTS="$here/.."
DETECT="$SCRIPTS/detect-repo.sh"
BOOTSTRAP="$SCRIPTS/bootstrap.sh"
VERIFY="$SCRIPTS/verify-repo.sh"
LINK="$SCRIPTS/link-skills.sh"
GITLAB_REMOTE="https://gitlab.example.test/acme-demo/widget"
GITHUB_REMOTE="https://github.example.test/acme-demo/widget"

commit_all() {
  git -C "$1" add -- .
  git -C "$1" commit -qm "${2:-fixture}"
}

new_fixture() {
  new_repo "$1"
  git -C "$1" checkout -q -b main
  [ -z "${2:-}" ] || git -C "$1" remote add origin "$2"
}

js_husky_gitlab() {
  new_fixture "$1" "$GITLAB_REMOTE"
  mkdir -p "$1/.husky" "$1/.gitlab/merge_request_templates"
  printf '{"name":"demo","scripts":{"lint":"eslint .","test":"vitest run","build":"tsc"}}\n' > "$1/package.json"
  printf 'lockfileVersion: 9\n' > "$1/pnpm-lock.yaml"
  printf '{"compilerOptions":{"strict":true}}\n' > "$1/tsconfig.json"
  printf "export default [{ rules: { 'max-params': ['error', 6] } }];\n" > "$1/eslint.config.js"
  printf '#!/usr/bin/env sh\nnpx lint-staged\n' > "$1/.husky/pre-commit"
  printf 'stages:\n  - test\n\ninclude:\n  - local: ci/base.yml\n\nunit:\n  script: [echo ok]\n' > "$1/.gitlab-ci.yml"
  printf '# Rules\n\nAlways add a comment above every function.\n' > "$1/AGENTS.md"
  printf '## Summary\n' > "$1/.gitlab/merge_request_templates/default.md"
  printf 'export const a = 1;\n' > "$1/index.ts"
  commit_all "$1"
}

python_precommit_github() {
  new_fixture "$1" "$GITHUB_REMOTE"
  mkdir -p "$1/.github/workflows" "$1/tests"
  printf '[tool.ruff]\nline-length = 100\n[tool.pytest.ini_options]\ntestpaths = ["tests"]\n' > "$1/pyproject.toml"
  printf 'repos: []\n' > "$1/.pre-commit-config.yaml"
  printf 'name: ci\non: push\njobs: {}\n' > "$1/.github/workflows/ci.yml"
  printf 'x = 1\n' > "$1/app.py"
  printf '.\n' > "$1/uv.lock"
  commit_all "$1"
}

go_bare() {
  new_fixture "$1"
  printf 'module example.test/demo\n' > "$1/go.mod"
  printf 'package main\n\nfunc main() {}\n' > "$1/main.go"
  commit_all "$1"
}

kotlin_maven() {
  new_fixture "$1" "$GITLAB_REMOTE"
  mkdir -p "$1/svc-a/src" "$1/svc-b/src"
  printf '<project><modelVersion>4</modelVersion><modules><module>svc-a</module><module>svc-b</module></modules></project>\n' > "$1/pom.xml"
  printf '<project></project>\n' > "$1/svc-a/pom.xml"
  printf '<project></project>\n' > "$1/svc-b/pom.xml"
  printf 'class A\n' > "$1/svc-a/src/A.kt"
  printf 'class B\n' > "$1/svc-b/src/B.kt"
  commit_all "$1"
}

shell_only() {
  new_fixture "$1"
  mkdir -p "$1/bin"
  printf '#!/usr/bin/env bash\necho hi\n' > "$1/bin/run.sh"
  commit_all "$1"
}

fake_clone() {
  local root="$1" name
  shift
  for name in "$@"; do
    mkdir -p "$root/skills/$name"
    printf -- '---\nname: %s\n---\n' "$name" > "$root/skills/$name/SKILL.md"
  done
}

step_action() { jq -r --arg id "$2" '.steps[] | select(.id == $id) | .action' <<<"$1"; }
step_ids() { jq -r '[.steps[].id] | join(" ")' <<<"$1"; }
summary() { jq -r --arg k "$2" '.summary[$k]' <<<"$1"; }
