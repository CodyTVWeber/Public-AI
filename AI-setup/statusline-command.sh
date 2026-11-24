#!/usr/bin/env bash

input=$(cat)

get()  { echo "$input" | jq -r "$1 // empty"; }
getn() { echo "$input" | jq -r "$1 // 0";     }

fmt_num() {
  local n=$1
  if   [ "$n" -ge 1000000 ] 2>/dev/null; then printf '%.1fM' "$(echo "scale=1; $n/1000000" | bc)"
  elif [ "$n" -ge 1000 ]    2>/dev/null; then printf '%.1fk' "$(echo "scale=1; $n/1000"    | bc)"
  else                                        printf '%s'    "$n"
  fi
}

fmt_duration() {
  local ms=$1
  local secs=$(( ms / 1000 ))
  local mins=$(( secs / 60 ))
  local hrs=$(( mins / 60 ))
  mins=$(( mins % 60 ))
  secs=$(( secs % 60 ))
  if [ "$hrs" -gt 0 ]; then printf '%dh%02dm' "$hrs" "$mins"
  elif [ "$mins" -gt 0 ]; then printf '%dm%02ds' "$mins" "$secs"
  else printf '%ds' "$secs"
  fi
}

CWD=$(get '.workspace.current_dir')
MODEL_NAME=$(get '.model.display_name')
MODEL_ID=$(get '.model.id')
VERSION=$(get '.version')
SESSION_NAME=$(get '.session_name')
OUTPUT_STYLE=$(get '.output_style.name')
VIM_MODE=$(get '.vim.mode')
AGENT_NAME=$(get '.agent.name')
AGENT_TYPE=$(get '.agent.type')
WORKTREE_NAME=$(get '.worktree.name')
WORKTREE_BRANCH=$(get '.worktree.branch')
USED_PCT=$(get '.context_window.used_percentage')
REMAINING_PCT=$(get '.context_window.remaining_percentage')
INPUT_TOKENS=$(getn '.context_window.current_usage.input_tokens')
OUTPUT_TOKENS=$(getn '.context_window.current_usage.output_tokens')
CACHE_READ=$(getn '.context_window.current_usage.cache_read_input_tokens')
CACHE_WRITE=$(getn '.context_window.current_usage.cache_creation_input_tokens')
CTX_SIZE=$(getn '.context_window.context_window_size')

COLS=$(tput cols 2>/dev/null || echo 120)

RESET='\033[0m'
BOLD='\033[1m'
BG='\033[48;5;245m'
W='\033[97m'
GR='\033[30m'
GN='\033[32m'
YL='\033[33m'
RD='\033[31m'
CY='\033[36m'
MG='\033[35m'
BL='\033[34m'

SEP="${GR}│${W}"

GIT_PART=""
if [ -n "$CWD" ] && git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" symbolic-ref --short HEAD 2>/dev/null \
           || GIT_OPTIONAL_LOCKS=0 git -C "$CWD" rev-parse --short HEAD 2>/dev/null)

  STAGED=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  DIRTY=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  UNTRACKED=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

  AHEAD=0; BEHIND=0
  if GIT_OPTIONAL_LOCKS=0 git -C "$CWD" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    AHEAD=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0)
    BEHIND=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)
  fi

  FLAGS=""
  [ "$STAGED"    -gt 0 ] && FLAGS="${FLAGS} ${GN}+${STAGED}"
  [ "$DIRTY"     -gt 0 ] && FLAGS="${FLAGS} ${YL}~${DIRTY}"
  [ "$UNTRACKED" -gt 0 ] && FLAGS="${FLAGS} ${RD}?${UNTRACKED}"
  [ "$AHEAD"     -gt 0 ] && FLAGS="${FLAGS} ${CY}↑${AHEAD}"
  [ "$BEHIND"    -gt 0 ] && FLAGS="${FLAGS} ${MG}↓${BEHIND}"

  if [ -n "$FLAGS" ]; then
    GIT_PART="${W}${BRANCH}${FLAGS}${W}"
  else
    GIT_PART="${GN}${BRANCH}${W}"
  fi
fi

DIR_PART=""
if [ -n "$CWD" ]; then
  DISPLAY_DIR="${CWD/#$HOME/~}"
  DIR_PART="${BOLD}${W}${DISPLAY_DIR}${RESET}${BG}${W}"
fi

CTX_PART=""
if [ -n "$USED_PCT" ]; then
  PCT_INT=$(printf '%.0f' "$USED_PCT")
  BAR_FILLED=$(( PCT_INT / 10 ))
  [ $BAR_FILLED -gt 10 ] && BAR_FILLED=10
  BAR_EMPTY=$(( 10 - BAR_FILLED ))

  BAR=""
  for i in $(seq 1 $BAR_FILLED); do BAR="${BAR}█"; done
  for i in $(seq 1 $BAR_EMPTY);  do BAR="${BAR}░"; done

  if   [ "$PCT_INT" -ge 90 ]; then BC="$RD"
  elif [ "$PCT_INT" -ge 70 ]; then BC="$YL"
  else                              BC="$GN"
  fi

  CTX_PART="${BC}${BAR} ${PCT_INT}%${W}"
fi

TOKEN_PART=""
if [ "$INPUT_TOKENS" -gt 0 ] || [ "$OUTPUT_TOKENS" -gt 0 ]; then
  IN_FMT=$(fmt_num "$INPUT_TOKENS")
  OUT_FMT=$(fmt_num "$OUTPUT_TOKENS")
  CR_FMT=$(fmt_num "$CACHE_READ")
  CTX_FMT=$(fmt_num "$CTX_SIZE")
  TOKEN_PART="${GR}in:${W}${IN_FMT} ${GR}out:${W}${OUT_FMT} ${GR}cached:${W}${CR_FMT} ${GR}/${W}${CTX_FMT}"
fi

MODEL_PART=""
[ -n "$MODEL_NAME" ] && MODEL_PART="${BOLD}${W}${MODEL_NAME}${RESET}${BG}${W}"

VERSION_PART=""
[ -n "$VERSION" ] && VERSION_PART="${GR}v${VERSION}${W}"

STYLE_PART=""
[ -n "$OUTPUT_STYLE" ] && STYLE_PART="${GR}style:${W}${OUTPUT_STYLE}"

SESSION_PART=""
[ -n "$SESSION_NAME" ] && SESSION_PART="${GR}session:${W}${SESSION_NAME}"

VIM_PART=""
if [ -n "$VIM_MODE" ]; then
  case "$VIM_MODE" in
    INSERT) VIM_PART="${GN}${BOLD}INSERT${RESET}${BG}${W}" ;;
    NORMAL) VIM_PART="${BL}${BOLD}NORMAL${RESET}${BG}${W}" ;;
    *)      VIM_PART="${YL}${BOLD}${VIM_MODE}${RESET}${BG}${W}" ;;
  esac
fi

AGENT_PART=""
if [ -n "$AGENT_NAME" ]; then
  AGENT_PART="${MG}⚡${AGENT_NAME}${W}"
  [ -n "$AGENT_TYPE" ] && AGENT_PART="${AGENT_PART}${GR}(${AGENT_TYPE})${W}"
fi

WORKTREE_PART=""
if [ -n "$WORKTREE_NAME" ]; then
  WORKTREE_PART="${MG}wt:${WORKTREE_NAME}${W}"
  [ -n "$WORKTREE_BRANCH" ] && WORKTREE_PART="${WORKTREE_PART}${GR}(${WORKTREE_BRANCH})${W}"
fi

TIME_PART="${GR}$(date '+%H:%M')${W}"

join() {
  local result=""
  for part in "$@"; do
    [ -z "$part" ] && continue
    if [ -z "$result" ]; then result="$part"
    else result="${result} ${SEP} ${part}"
    fi
  done
  echo "$result"
}

GROUP_A=$(join "$MODEL_PART" "$VERSION_PART" "$STYLE_PART" "$CTX_PART" "$TOKEN_PART" "$TIME_PART")

GROUP_B=$(join "$DIR_PART" "$GIT_PART" "$WORKTREE_PART" "$SESSION_PART" "$VIM_PART" "$AGENT_PART")

print_line() {
  [ -z "$1" ] && return
  printf "${BG}${W} %b ${RESET}\n" "$1"
}

strip_ansi() {
  printf '%b' "$1" | sed $'s/\033\[[0-9;]*m//g'
}

COMBINED=$(join "$MODEL_PART" "$VERSION_PART" "$STYLE_PART" "$CTX_PART" "$TOKEN_PART" "$DIR_PART" "$GIT_PART" "$WORKTREE_PART" "$SESSION_PART" "$VIM_PART" "$AGENT_PART" "$TIME_PART")
VISIBLE=$(strip_ansi "$COMBINED")
COMBINED_LEN=${#VISIBLE}

if [ "$COMBINED_LEN" -le "$COLS" ]; then
  print_line "$COMBINED"
else
  print_line "$GROUP_A"
  print_line "$GROUP_B"
fi
