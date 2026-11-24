die() {
  printf '%s\n' "$2" >&2
  exit "$1"
}

need() {
  command -v "$1" >/dev/null 2>&1 || die 3 "missing tool: $1"
}

git_init() {
  need git
  need jq
  git rev-parse --git-dir >/dev/null 2>&1 || die 3 "not a git repository"
}

forge_init() {
  git_init
  local url p
  url=$(git config --get remote.origin.url || true)
  [ -n "$url" ] || die 3 "no origin remote"
  case "${PIR_FORGE:-}" in
    gitlab | github) FORGE=$PIR_FORGE ;;
    *)
      case $(printf '%s' "$url" | tr '[:upper:]' '[:lower:]') in
        *github*) FORGE=github ;;
        *gitlab*) FORGE=gitlab ;;
        *) die 3 "cannot detect forge from origin url; set PIR_FORGE=gitlab|github" ;;
      esac
      ;;
  esac
  if [ "$FORGE" = gitlab ]; then CLI=glab; else CLI=gh; fi
  case "$url" in
    *://*)
      p=${url#*://}
      p=${p#*@}
      p=${p#*/}
      ;;
    *)
      p=${url#*@}
      p=${p#*:}
      ;;
  esac
  p=${p%/}
  PROJECT=${p%.git}
}

forge_need_cli() {
  need "$CLI"
}

forge_default_branch() {
  local ref b
  if ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); then
    printf '%s\n' "${ref#origin/}"
    return 0
  fi
  for b in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$b"; then
      printf '%s\n' "$b"
      return 0
    fi
  done
  if [ "${1:-}" = online ]; then
    b=$(git ls-remote --symref origin HEAD 2>/dev/null | awk '/^ref:/{sub("refs/heads/","",$2);print $2;exit}')
    if [ -n "$b" ]; then
      printf '%s\n' "$b"
      return 0
    fi
  fi
  return 1
}

slurp_arrays() {
  jq -s 'map(if type == "array" then . else [.] end) | add // []'
}

forge_api() {
  if [ "$FORGE" = gitlab ]; then
    glab api --paginate "$1" | slurp_arrays
  else
    gh api --paginate "$1" | slurp_arrays
  fi
}

forge_list_open() {
  if [ "$FORGE" = gitlab ]; then
    glab api --paginate "projects/:id/merge_requests?state=opened&per_page=100" | slurp_arrays |
      jq -c 'map({number: .iid, url: .web_url, branch: .source_branch, title: .title, base: .target_branch})'
  else
    gh pr list --state open --limit 1000 --json number,url,headRefName,title,baseRefName |
      jq -c 'map({number: .number, url: .url, branch: .headRefName, title: .title, base: .baseRefName})'
  fi
}

forge_number_for_branch() {
  forge_list_open | jq -r --arg b "$1" 'map(select(.branch == $b)) | .[0].number // empty'
}
