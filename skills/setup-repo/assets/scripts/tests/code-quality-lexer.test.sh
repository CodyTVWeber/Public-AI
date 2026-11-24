#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp

comment_count() { "$CQ" --all-lines "$TMPROOT/$1" 2>/dev/null | jq '[.findings[] | select(.rule == "added-comment")] | length'; }

fx lifetimes.rs <<'FIX'
fn longest<'a>(left: &'a str, right: &'a str) -> &'a str {
    let quote = '"';
    let slash = "// not a comment";
    if left.len() > right.len() { left } else { right }
}
FIX
expect_clean "rust lifetimes, char quotes and slashes in strings" lifetimes.rs

fx raw.go <<'FIX'
package main

var pattern = `// not a comment
still raw "quote"`

func name() string {
	return "x"
}
FIX
expect_clean "go raw string spans lines" raw.go

fx Raw.kt <<'FIX'
val sql = """
    select * from items -- not a comment // nor this
"""

fun name(): String = sql
FIX
expect_clean "kotlin raw string spans lines" Raw.kt

fx query.py <<'FIX'
QUERY = """
select 1
"""


def run(db):
    text = f"# {db}"
    return db.execute(QUERY + text)
FIX
expect_clean "python triple-quoted data and hash in string are not comments" query.py

fx block.ts <<'FIX'
/*
 * first line
 * second line
 */
export const a = 1;
export const b = 2; /* trailing */
FIX
assert_eq "a block comment is one finding, a trailing one is another" "2" "$(comment_count block.ts)"

fx view.tsx <<'FIX'
export const View = () => <div>{/* note */}http://example.test</div>;
FIX
assert_eq "jsx comment found, url text ignored" "1" "$(comment_count view.tsx)"

fx printf.c <<'FIX'
int main(void) {
    printf("%d // not a comment\n", 1);
    return 0;
}
FIX
expect_clean "c format string with slashes" printf.c

fx heredoc.sh <<'FIX'
#!/usr/bin/env bash
cat <<-EOT
	# tab-indented heredoc line
	EOT
cat <<"QUOTED"
# quoted delimiter body
QUOTED
printf '%s\n' "$#" "${#BASH_SOURCE[@]}"
FIX
expect_clean "shell heredoc variants and hash expansions" heredoc.sh

fx later.sh <<'FIX'
#!/usr/bin/env bash
cat <<'EOT'
# data
EOT
echo ok # after the heredoc
FIX
assert_eq "comment after a heredoc is found" "1" "$(comment_count later.sh)"

fx crlf.ts <<'FIX'
export const a = 1;
FIX
printf 'export const a = 1;\r\n// note\r\n' > "$TMPROOT/crlf.ts"
assert_eq "crlf files are read" "1" "$(comment_count crlf.ts)"
finish
