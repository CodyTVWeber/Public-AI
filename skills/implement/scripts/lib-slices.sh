SLICE_NAME_RE='^[a-z0-9]+(-[a-z0-9]+)*$'

die() {
  printf '%s\n' "$2" >&2
  exit "$1"
}

need_tools() {
  command -v git >/dev/null 2>&1 || die 3 "missing tool: git"
  command -v jq >/dev/null 2>&1 || die 3 "missing tool: jq"
  git rev-parse --git-dir >/dev/null 2>&1 || die 3 "not a git repository"
}

valid_name() {
  [[ $1 =~ $SLICE_NAME_RE ]]
}

check_topic() {
  valid_name "$1" || die 2 "invalid topic: $1"
}

check_mode() {
  case "$1" in
    worktree | clone) ;;
    *) die 2 "invalid mode: $1" ;;
  esac
}

load_slices() {
  local name seen=" "
  [ -n "$1" ] || die 2 "--slices is required"
  IFS=, read -ra SLICES <<<"$1"
  for name in "${SLICES[@]}"; do
    valid_name "$name" || die 2 "invalid slice name: $name"
    case "$seen" in *" $name "*) die 2 "duplicate slice: $name" ;; esac
    seen="$seen$name "
  done
}

default_root() {
  local base=${TMPDIR:-/tmp}
  if [ "${2:-worktree}" = clone ]; then base=${XDG_CACHE_HOME:-${HOME:?}/.cache}; fi
  printf '%s/pir-%s/wt\n' "${base%/}" "$1"
}

abs_path() {
  local p=$1 rest=""
  case "$p" in /*) ;; *) p=$PWD/$p ;; esac
  while [ ! -d "$p" ]; do
    rest="/$(basename "$p")$rest"
    p=$(dirname "$p")
  done
  printf '%s%s\n' "$(cd "$p" && pwd -P)" "$rest"
}

require_main_checkout() {
  local gd common
  gd=$(cd "$(git rev-parse --absolute-git-dir)" && pwd -P)
  common=$(cd "$(git rev-parse --path-format=absolute --git-common-dir)" && pwd -P)
  [ "$gd" = "$common" ] || die 3 "run from the main checkout, not a linked worktree"
}

require_clean() {
  local dirty
  dirty=$(git status --porcelain)
  [ -z "$dirty" ] || die 3 "dirty working tree:
$dirty"
}

require_outside_repo() {
  local top
  top=$(cd "$(git rev-parse --show-toplevel)" && pwd -P)
  case "$1/" in "$top"/*) die 3 "root is inside the repository: $1" ;; esac
  case "$top/" in "$1"/*) die 3 "root contains the repository: $1" ;; esac
}

require_branch() {
  git show-ref --verify --quiet "refs/heads/$1" || die 3 "branch not found: $1"
}

slice_branch() {
  printf '%s--%s\n' "$1" "$2"
}

slice_ref() {
  printf 'refs/pir/%s/%s\n' "$1" "$2"
}

manifest_path() {
  printf '%s/manifest.json\n' "$1"
}

manifest_get() {
  local file
  file=$(manifest_path "$1")
  [ -f "$file" ] || return 0
  jq -r "$2 // empty" "$file"
}

topic_worktrees() {
  git worktree list --porcelain | awk -v root="$1/" 'index($0, "worktree " root) == 1'
}

json_array() {
  local item out="[]"
  for item in "$@"; do
    out=$(jq -c --arg v "$item" '. + [$v]' <<<"$out")
  done
  printf '%s\n' "$out"
}
