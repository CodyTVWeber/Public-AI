#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: new-doc.sh spec|adr|glossary|alignment <topic> [--slug S] [--date YYYY-MM-DD] [--root DIR]
       new-doc.sh -h|--help

Scaffolds one doc from assets/templates and prints JSON:
  {kind, path, topic_dir, adr_dir, convention}
Never overwrites. spec, glossary and alignment exist already -> exit 3.
An adr gets the file name <date>-<slug>.md; a name taken the same day gets -2, -3, ...

Layout (detected, named in `convention`):
  topic dir   <docs root>/align/<topic-slug>/ where docs root is the existing docs/ or doc/, else docs/
  adr dir     an existing docs/adr/ or adr/ (shared with the repo), else <topic dir>/adr/
--slug S    adr file slug (default: the topic slug); the adr title is the slug words
--date D    adr and header date (default: today)
--root DIR  repo root (default: git top level, else the current directory)

Fill-ins are {{...}}: check-align.sh reports any left in place.
Exit: 0 ok, 2 usage, 3 precondition (file exists, root or templates missing)
USAGE
}

KIND="" TOPIC="" SLUG="" DATE="" ROOT="" DOCS_ROOT="" TOPIC_DIR="" ADR_DIR=""
TEMPLATES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../assets/templates" && pwd)"

die() { echo "new-doc: $1" >&2; exit "${2:-2}"; }

slugify() {
  tr '[:upper:]' '[:lower:]' <<<"$1" | tr -cs '[:alnum:]' '-' | sed 's/^-*//;s/-*$//'
}

docs_root_of() {
  if [[ -d "$ROOT/docs" ]]; then echo docs
  elif [[ -d "$ROOT/doc" ]]; then echo doc
  else echo docs
  fi
}

adr_dir_of() {
  if [[ -d "$ROOT/docs/adr" ]]; then echo docs/adr
  elif [[ -d "$ROOT/adr" ]]; then echo adr
  else echo "$TOPIC_DIR/adr"
  fi
}

convention_of() {
  local docs_note adr_note
  if [[ -d "$ROOT/$DOCS_ROOT" ]]; then docs_note="existing $DOCS_ROOT/"; else docs_note="default $DOCS_ROOT/"; fi
  case "$ADR_DIR" in
    docs/adr|adr) adr_note="shared existing $ADR_DIR/" ;;
    *) adr_note="topic adr/" ;;
  esac
  echo "$docs_note, $adr_note"
}

render() {
  local body title="$TOPIC"
  [[ "$KIND" == adr ]] && title="${SLUG//-/ }"
  body="$(cat "$TEMPLATES/$KIND.md")"
  body="${body//\{\{TITLE\}\}/$title}"
  body="${body//\{\{DATE\}\}/$DATE}"
  printf '%s\n' "$body"
}

write_new() {
  local target="$1" content="$2"
  mkdir -p "$(dirname "$target")"
  if ! (set -o noclobber; printf '%s' "$content" > "$target") 2>/dev/null; then
    die "exists, not overwriting: $target" 3
  fi
}

free_adr_name() {
  local name n=1
  name="$DATE-$SLUG.md"
  while [[ -e "$ROOT/$ADR_DIR/$name" ]]; do
    n=$((n + 1))
    name="$DATE-$SLUG-$n.md"
  done
  echo "$name"
}

target_of() {
  if [[ "$KIND" == adr ]]; then echo "$ADR_DIR/$(free_adr_name)"
  else echo "$TOPIC_DIR/$KIND.md"
  fi
}

set_option() {
  [[ -n "${2:-}" ]] || die "$1 needs a value"
  case "$1" in --slug) SLUG="$2" ;; --date) DATE="$2" ;; *) ROOT="$2" ;; esac
}

set_positional() {
  if [[ -z "$KIND" ]]; then KIND="$1"
  elif [[ -z "$TOPIC" ]]; then TOPIC="$1"
  else die "extra argument: $1"
  fi
}

parse_args() {
  DATE="$(date +%F)"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --slug|--date|--root) set_option "$1" "${2:-}"; shift 2 ;;
      -*) die "unknown option: $1" ;;
      *) set_positional "$1"; shift ;;
    esac
  done
}

validate() {
  case "$KIND" in spec|adr|glossary|alignment) ;; *) usage >&2; exit 2 ;; esac
  [[ -n "$TOPIC" && -n "$(slugify "$TOPIC")" ]] || die "topic needed"
  [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "bad --date: $DATE"
  ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  [[ -d "$ROOT" ]] || die "not a directory: $ROOT" 3
  ROOT="$(cd "$ROOT" && pwd)"
  [[ -f "$TEMPLATES/$KIND.md" ]] || die "missing template: $KIND" 3
  SLUG="$(slugify "${SLUG:-$TOPIC}")"
}

main() {
  parse_args "$@"
  validate
  DOCS_ROOT="$(docs_root_of)"
  TOPIC_DIR="$DOCS_ROOT/align/$(slugify "$TOPIC")"
  ADR_DIR="$(adr_dir_of)"
  local convention target
  convention="$(convention_of)"
  target="$(target_of)"
  write_new "$ROOT/$target" "$(render)"$'\n'
  jq -n --arg kind "$KIND" --arg path "$target" --arg topic_dir "$TOPIC_DIR" \
    --arg adr_dir "$ADR_DIR" --arg convention "$convention" \
    '{kind:$kind, path:$path, topic_dir:$topic_dir, adr_dir:$adr_dir, convention:$convention}'
}

main "$@"
