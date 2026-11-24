#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: classify-tier.sh [base-ref] [-h|--help]
       classify-tier.sh --files <path>...

Classifies paths by risk tier (rules/risk-tiers.md); the change takes the highest tier.
Paths come from `git diff` against the merge-base with base-ref (default: origin default
branch, else main/master), including uncommitted and untracked files, or from --files.
Prints JSON: {"tier","reasons":[{"path","tier","why"}],"policy":{...},"approver"}
  policy    merge-policy.sh output; approver says who may merge that tier under it
Unmatched paths are medium. No paths: tier low, reasons [].
Order of evaluation, first match wins per path:
  1 high   agent rules and control: AGENTS.md CLAUDE.md GEMINI.md, .claude/ .cursor/, skills/,
           SKILL.md, rules/, docs/rules/, CODEOWNERS, .github/ .gitlab/ .circleci/ .buildkite/
           CI files (.gitlab-ci.yml, Jenkinsfile, azure-pipelines.yml), git hooks (.githooks/
           .husky/ lefthook, .pre-commit-config.yaml)
  2 low    tests: test/ tests/ __tests__/ spec/ e2e/ fixtures/ dirs; *.test.* *.spec.*
           *_test.* test_* *Test.* *Tests.* files
  3 high   migrations/ migrate/ alembic/ prisma/, *.sql under db/ or database/; auth, authn,
           authz, oauth, iam, rbac, acl, permissions, security path segments or file stems;
           secrets: .env* (not .env.example), secrets/, *.pem *.key *.tfvars; scheduled jobs:
           cron/, crontab, scheduled/; production config: prod/production in config names;
           build and run: Dockerfile*, docker-compose*, Makefile, *.tf, k8s/, helm/, terraform/;
           dependency manifests: package.json pom.xml build.gradle* Cargo.toml pyproject.toml
           requirements*.txt go.mod Gemfile; data-store scripts: scripts/ names containing
           backup restore apply seed schedule
  4 low    docs and copy: *.md *.txt *.rst, docs/, README*, *.css *.scss *.less, locales/ i18n/,
           images
  5 medium lockfiles and everything else (application code)
Exit: 0 classified, 2 usage, 3 no base ref found (precondition)
EOF
}

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base=""
files=()
use_files=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --files) use_files=1; shift; while [ $# -gt 0 ]; do files+=("$1"); shift; done ;;
    -*) usage >&2; exit 2 ;;
    *) base="$1"; shift ;;
  esac
done

classify() {
  local p="$1" lc base
  lc="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')"
  base="${lc##*/}"

  case "/$lc" in
    */agents.md|*/claude.md|*/gemini.md|*/.claude/*|*/.cursor/*|*/.cursorrules|*/skills/*|*/skill.md|*/rules/*|*/codeowners|*/.github/*|*/.gitlab/*|*/.circleci/*|*/.buildkite/*|*/.gitlab-ci.yml|*/jenkinsfile|*/azure-pipelines.yml|*/.githooks/*|*/.husky/*|*/lefthook.yml|*/.pre-commit-config.yaml|*/.git/hooks/*)
      echo "high|agent rules, CI, or git hooks: governs how work is built, checked or run"; return ;;
  esac
  case "/$lc" in
    */test/*|*/tests/*|*/__tests__/*|*/spec/*|*/specs/*|*/e2e/*|*/fixtures/*|*/__mocks__/*) echo "low|tests only"; return ;;
  esac
  case "$p" in
    *Test.*|*Tests.*) echo "low|tests only"; return ;;
  esac
  case "$base" in
    *.test.*|*.spec.*|*_test.*|*_spec.*|test_*) echo "low|tests only"; return ;;
  esac
  case "/$lc" in
    */migrations/*|*/migrate/*|*/alembic/*|*/prisma/*|*/db/*.sql|*/database/*.sql) echo "high|schema migration or database definition"; return ;;
    */secrets/*|*/.env|*/.env.*|*.pem|*.key|*.tfvars)
      case "$base" in .env.example|.env.sample|.env.template) ;; *) echo "high|secret storage or environment config"; return ;; esac ;;
    */cron/*|*/crontab|*/scheduled/*|*/cronjobs/*) echo "high|scheduled job"; return ;;
    */dockerfile*|*/docker-compose*|*/makefile|*.tf|*/k8s/*|*/helm/*|*/terraform/*) echo "high|build, run or infrastructure definition"; return ;;
    */package.json|*/pom.xml|*/build.gradle|*/build.gradle.kts|*/cargo.toml|*/pyproject.toml|*/requirements*.txt|*/go.mod|*/gemfile) echo "high|dependency manifest (a pure version bump of an existing dependency is low: judge the diff)"; return ;;
  esac
  if [[ "/$lc" =~ /(auth|authn|authz|oauth|iam|rbac|acl|permissions|security|authentication|authorization)(/|\.|-|_|$) ]]; then
    echo "high|auth or access control"; return
  fi
  if [[ "$lc" =~ (^|/)config/[^/]*(prod|production) ]] || [[ "$base" =~ (^|[._-])(prod|production)([._-]|$) ]]; then
    case "$base" in *.md|*.txt) ;; *) echo "high|config that can point at production"; return ;; esac
  fi
  case "/$lc" in
    */scripts/*|*/bin/*)
      if [[ "$base" =~ (backup|restore|apply|seed|schedule) ]]; then echo "high|script that applies, backs up, restores or schedules a data store"; return; fi ;;
  esac
  case "/$lc" in
    */docs/*|*/doc/*|*/readme*|*/locales/*|*/i18n/*) echo "low|docs or copy"; return ;;
  esac
  case "$base" in
    *.md|*.txt|*.rst|*.css|*.scss|*.less|*.svg|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico) echo "low|docs, copy or styling"; return ;;
    package-lock.json|yarn.lock|pnpm-lock.yaml|*.lock|*lock.json|*lock.yaml) echo "medium|lockfile: confirm no new top-level dependency"; return ;;
  esac
  echo "medium|application code or unmatched path"
}

rank() { case "$1" in low) echo 1 ;; medium) echo 2 ;; high) echo 3 ;; esac; }

if [ "$use_files" -eq 0 ]; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "classify-tier: not a git repo" >&2; exit 3; }
  if [ -z "$base" ]; then
    for ref in "$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)" origin/main origin/master main master; do
      [ -n "$ref" ] && git rev-parse --verify --quiet "$ref" >/dev/null && { base="$ref"; break; }
    done
  fi
  [ -n "$base" ] || { echo "classify-tier: no base ref found; pass one or use --files" >&2; exit 3; }
  mb="$(git merge-base "$base" HEAD 2>/dev/null)" || { echo "classify-tier: cannot resolve base: $base" >&2; exit 3; }
  while IFS= read -r -d '' f; do files+=("$f"); done < <(
    git diff --name-only -z "$mb" --
    git ls-files --others --exclude-standard -z
  )
fi

top=0
rows=""
for f in "${files[@]+"${files[@]}"}"; do
  res="$(classify "$f")"
  tier="${res%%|*}"
  why="${res#*|}"
  r="$(rank "$tier")"
  [ "$r" -gt "$top" ] && top="$r"
  rows="$rows$(jq -nc --arg p "$f" --arg t "$tier" --arg w "$why" '{path:$p,tier:$t,why:$w}')"$'\n'
done

case "$top" in 3) tier=high ;; 2) tier=medium ;; *) tier=low ;; esac
policy="$("$here/merge-policy.sh")"
profile="$(printf '%s' "$policy" | jq -r .profile)"
auto="$(printf '%s' "$policy" | jq -r .auto_merge_low)"

case "$profile:$tier" in
  conservative:low|conservative:medium) approver="one approval from a person who is not the author; a person merges" ;;
  conservative:high) approver="one approval minimum, a second is the norm; written rollback note; a person merges" ;;
  balanced:low) if [ "$auto" = true ]; then approver="a person merges, or an agent when every low-tier auto-merge condition holds"; else approver="a person merges"; fi ;;
  balanced:medium) approver="a second person (maintainer, not the author) approves; then that person's agent may merge" ;;
  balanced:high) approver="designated owner only, in a local session with the owner present" ;;
  yolo:*) approver="none: the agent merges" ;;
esac

printf '%s' "$rows" | jq -sc --arg tier "$tier" --argjson policy "$policy" --arg approver "$approver" \
  '{tier:$tier,reasons:.,policy:$policy,approver:$approver}'
