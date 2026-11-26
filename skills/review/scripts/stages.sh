#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: stages.sh <base>
Pick the review skills that apply to `git diff <base>...HEAD` from changed paths and added lines.
Always on: plan, proof. Each stage maps to the skill review-<id>.
Turned on by a match:
  logic             REVIEW_LOGIC_MIN (default 5) or more added lines in non-test code
  non-happy-logic   logic is on and added lines handle errors, nulls, validation, timeouts or external calls
  tests             code changed (REVIEW_LOGIC_MIN) or test files changed
  security          auth/crypto/secret paths, risky tokens or string-built SQL in added lines
  data              schema, migration, model or query paths, schema statements in added lines
  ui                UI files
  dependencies      manifest or lockfile
  infra             CI, Docker, IaC, env or deploy config, env and flag reads
  concurrency       locks, async, cache, retry, unbounded queries in added lines
  code-quality      any code or docs file changed
Docs lines never trigger content signals.
stdout: {base, changed, added_code_lines, stages:[{id, skill, active, reason, files[]}]} in review order.
exit: 0 ok, 2 usage, 3 precondition (not a repo, bad base)
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  "" | -*)
    usage >&2
    exit 2
    ;;
esac
[ "$#" -eq 1 ] || {
  usage >&2
  exit 2
}

base=$1
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "not a git repository" >&2
  exit 3
}
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || {
  echo "base ref not found: $base" >&2
  exit 3
}
logic_min=${REVIEW_LOGIC_MIN:-5}

signals=$(mktemp)
trap 'rm -f "$signals"' EXIT

git diff -U0 --no-color --no-ext-diff "$base...HEAD" | awk '
function hit(stage, why) { print stage "\t" file "\t" why }
function is_test(p) { return p ~ /(^|\/)(tests?|spec|__tests__|e2e)\// || p ~ /\.(test|spec)\.|_test\.|_spec\.|(^|\/)test_|tests?\.[a-z]+$/ }
function is_docs(p) { return p ~ /\.(md|mdx|rst|txt|adoc)$/ || p ~ /(^|\/)docs\// || p ~ /(^|\/)(license|changelog)/ }
function is_code(p) { return p ~ /\.(java|kt|kts|scala|go|py|rb|rs|cs|php|ex|exs|swift|ts|tsx|js|jsx|mjs|cjs|vue|svelte|sh|sql)$/ }
/^diff --git / {
  line = $0
  sub(/^diff --git a\/.* b\//, "", line)
  file = line
  lower = tolower(file)
  hit("changed", "")
  counts = !is_test(lower) && !is_docs(lower) && is_code(lower)
  if (is_test(lower)) hit("tests", "test file changed")
  else if (counts) hit("code", "")
  if (is_docs(lower) || is_code(lower)) hit("quality", "code or docs changed")
  if (lower ~ /(auth|login|session|oauth|crypto|secur|permission|rbac|jwt|credential|secret)/) hit("security", "security-sensitive path")
  if (lower ~ /\.(sql|prisma)$/ || lower ~ /(^|\/)(migrations?|db\/migrate|flyway|liquibase|schemas?|entit(y|ies)|models?|repositor(y|ies))(\/|\.)/) hit("data", "schema, model or migration path")
  if (lower ~ /\.(tsx|jsx|vue|svelte|html|css|scss|sass|less|svg|hbs|erb|ftl)$/ || lower ~ /\.stories\.|(^|\/)(components|pages|views|templates|styles)\//) hit("ui", "UI path")
  if (lower ~ /(^|\/)(package(-lock)?\.json|yarn\.lock|pnpm-lock\.yaml|pom\.xml|build\.gradle(\.kts)?|settings\.gradle(\.kts)?|go\.(mod|sum)|requirements[^\/]*\.txt|pipfile(\.lock)?|poetry\.lock|pyproject\.toml|cargo\.(toml|lock)|gemfile(\.lock)?|composer\.(json|lock)|packages\.lock\.json)$/ || lower ~ /\.csproj$/) hit("dependencies", "manifest or lockfile")
  if (lower ~ /dockerfile|docker-compose|\.tfvars?$|\.tf$|(^|\/)(\.github|\.circleci|helm|k8s|kubernetes|deploy|terraform|ansible)\/|\.gitlab-ci|jenkinsfile|(^|\/)\.env|application[-.a-z]*\.(ya?ml|properties)$|nginx|\.conf$/) hit("infra", "build, deploy or runtime config path")
  next
}
/^\+\+\+ / { next }
/^\+/ {
  text = tolower(substr($0, 2))
  if (is_docs(lower)) next
  if (counts && text ~ /[^ \t]/) print "added\t" file "\t"
  if (text ~ /password|passwd|secret|api[_-]?key|private[_ -]?key|bearer |eval\(|exec\(|innerhtml|dangerouslysetinnerhtml|child_process|subprocess|os\.system|runtime\.exec|pickle\.load|yaml\.load\(|md5|sha-?1|math\.random|verify *= *false|rejectunauthorized|permitall/) hit("security", "risky token in added line")
  if (text ~ /(select|insert into|update|delete from) .*(\+ |\$\{|%s|\{\})/) { hit("security", "SQL built from strings"); hit("data", "SQL built from strings") }
  if (text ~ /(alter|create|drop) +(table|index)|add column|@entity|@table|foreign key|@transactional/) hit("data", "schema or transaction statement")
  if (text ~ /process\.env|getenv|feature[_.-]?flag|toggle/) hit("infra", "env or flag read")
  if (counts && text ~ /catch|except |rescue|throw |raise |panic|err != |error|timeout|\bnull\b|\bnil\b|undefined|isempty|\.length|validate|fetch\(|axios|requests\.|httpclient|resttemplate|\.exec\(|retry/) hit("nonhappy", "error, boundary or external-call handling added")
  if (text ~ /synchronized|new thread|executorservice|mutex|\block\(|go func|@async|promise\.all|setinterval|@cacheable|\bcache\b|findall\(|select \*|for .*await|while *\(true\)|retry|backoff|parallelstream/) hit("concurrency", "concurrency, cache, retry or unbounded query")
}
' >"$signals"

jq -Rn --arg base "$base" --argjson min "$logic_min" '
  [inputs | split("\t") | {id: .[0], file: .[1], why: .[2]}] as $rows
  | def files($id): [$rows[] | select(.id == $id and .file != "") | .file] | unique;
  def on($id): $rows | any(.id == $id);
  def why($id; $none): ([$rows[] | select(.id == $id and .why != "") | .why] | unique | join("; ")) as $w | if $w == "" then $none else $w end;
  def stage($id; $on; $reason; $files): {id: $id, skill: ("review-" + $id), active: $on, reason: $reason, files: $files};
  def signal($id; $none): stage($id; on($id); why($id; $none); files($id));
  ([$rows[] | select(.id == "added")] | length) as $added
  | ($added >= $min) as $logic
  | on("tests") as $tests
  | {base: $base, changed: (files("changed") | length), added_code_lines: $added, stages: [
      stage("plan"; true; "always"; []),
      stage("logic"; $logic; (if $logic then ($added | tostring) + " added code lines" else "under " + ($min | tostring) + " added code lines" end); files("code")),
      stage("non-happy-logic"; ($logic and on("nonhappy")); (if $logic and on("nonhappy") then why("nonhappy"; "") else "no error, boundary or external-call handling added" end); files("nonhappy")),
      stage("tests"; ($logic or $tests); (if $logic and ($tests | not) then "code changed, no test files touched" elif $tests then "test files changed" else "no code or tests changed" end); files("tests")),
      signal("security"; "no security signal"),
      signal("data"; "no schema or query signal"),
      signal("ui"; "no UI files"),
      signal("dependencies"; "no manifest or lockfile"),
      signal("infra"; "no config or deploy change"),
      signal("concurrency"; "no concurrency or query signal"),
      stage("code-quality"; on("quality"); why("quality"; "no code or docs changed"); []),
      stage("proof"; true; "always"; [])
    ]}
' <"$signals"
