#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp

fx comment.ts <<'FIX'
export const keep = 1;
// explains the next line
export const next = 2;
FIX
expect_rule "ts comment blocked" comment.ts added-comment

fx directive.ts <<'FIX'
// eslint-disable-next-line no-empty -- empty probe is the signal
export const keep = 1;
// SPDX-License-Identifier: MIT
export const next = 2;
FIX
expect_no_rule "directive with reason and SPDX allowed" directive.ts added-comment

fx bare.ts <<'FIX'
// eslint-disable-next-line no-empty
export const keep = 1;
FIX
expect_rule "bare directive blocked" bare.ts added-comment

fx marker.ts <<'FIX'
// TODO: handle retries
export const keep = 1;
FIX
expect_rule "todo marker" marker.ts todo-marker
expect_no_rule "todo is not also a plain comment" marker.ts added-comment

fx banner.ts <<'FIX'
// ==========
export const keep = 1;
// STATUS: draft
export const next = 2;
FIX
expect_rule "banner" banner.ts banner

fx strings.ts <<'FIX'
export const url = "http://example.test/a//b";
export const note = '// not a comment';
export const tpl = `multi
// still text
line`;
FIX
expect_clean "slashes inside strings are not comments" strings.ts

fx catch.ts <<'FIX'
export function probe() {
  try {
    return load();
  } catch (err) {
  }
}
export const quiet = () => load().catch(() => {});
FIX
expect_rule "empty catch ts" catch.ts empty-catch

fx handled.ts <<'FIX'
export function probe() {
  try {
    return load();
  } catch (err) {
    return ignoreOptionalFailure(err);
  }
}
FIX
expect_no_rule "handled catch passes" handled.ts empty-catch
finish
