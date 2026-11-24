#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp

fx tool.sh <<'FIX'
#!/usr/bin/env bash
# explains
set -u

helper() {
  local a="$1" b="$2" c="$3" d="$4"
  if [ -n "$a" ]; then
    for x in 1 2; do
      while true; do
        if [ "$x" ]; then
          echo "$b$c$d"
        fi
      done
    done
  fi
}

cat <<'EOT'
## heading inside a heredoc
# another line of data
EOT
echo ok
FIX
expect_rule "bash comment" tool.sh added-comment
expect_rule "bash params" tool.sh param-count
expect_rule "bash nesting" tool.sh nesting-depth
assert_eq "heredoc body and shebang are not comments" "1" "$("$CQ" --all-lines "$TMPROOT/tool.sh" 2>/dev/null | jq '[.findings[] | select(.rule == "added-comment")] | length')"

fx quiet.sh <<'FIX'
#!/usr/bin/env bash
# shellcheck disable=SC2034 -- exported for callers
set -u

run() {
  echo "$1"
}

cat <<EOT
# heading
EOT
run "x" 
FIX
expect_clean "shebang, directive with reason and heredoc allowed" quiet.sh

fx vars.sh <<'FIX'
#!/usr/bin/env bash
copy() {
  cp "$source_dir" "$target_dir"
  mv "$source_dir" "$target_dir"
  rm "$source_dir" "$target_dir"
}
FIX
expect_no_rule "shell variable strings are not duplicates" vars.sh duplicate-string

fx words.sh <<'FIX'
#!/usr/bin/env bash
echo "same message here"
echo "same message here"
echo "same message here"
FIX
expect_rule "repeated shell message is a duplicate" words.sh duplicate-string

fx task.rb <<'FIX'
class Task
  def run(a, b, c, d)
    if a
      b
    end
  end
end
FIX
expect_rule "ruby params" task.rb param-count

fx skipped.min.js <<'FIX'
// generated
var a=1;
FIX
expect_clean "generated min file skipped" skipped.min.js
finish
