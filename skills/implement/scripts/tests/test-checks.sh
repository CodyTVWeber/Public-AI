#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0
fail=0

check() {
  local name="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $name: want $want got $got" >&2; fi
}

mkpng() {
  node - "$1" "$2" "$3" <<'JS'
const { writeFileSync } = require("node:fs");
const { randomBytes } = require("node:crypto");
const { deflateSync, crc32 } = require("node:zlib");

const [path, size, seed] = [process.argv[2], process.argv[3], Number(process.argv[4])];
const [w, h] = size.split("x").map(Number);
const rows = Array.from({ length: h }, () => Buffer.concat([Buffer.from([0]), seed ? randomBytes(3 * w) : Buffer.alloc(3 * w)]));

function chunk(type, data) {
  const t = Buffer.from(type, "latin1");
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(w, 0);
ihdr.writeUInt32BE(h, 4);
ihdr.set([8, 2, 0, 0, 0], 8);
writeFileSync(path, Buffer.concat([
  Buffer.from("89504e470d0a1a0a", "hex"),
  chunk("IHDR", ihdr),
  chunk("IDAT", deflateSync(Buffer.concat(rows))),
  chunk("IEND", Buffer.alloc(0)),
]));
JS
}

run() { set +e; "$@" >"$tmp/out" 2>"$tmp/err"; code=$?; set -e; }

mkpng "$tmp/a.png" 40x30 1
mkpng "$tmp/b.png" 40x30 1
mkpng "$tmp/blank.png" 4x4 0
: >"$tmp/zero.png"
cp "$tmp/a.png" "$tmp/a-copy.png"

run "$here/evidence-check.sh" "$tmp/a.png"
check ev-ok "0" "$code"
check ev-dims "40x30" "$(jq -r '.files[0] | "\(.width)x\(.height)"' "$tmp/out")"
check ev-sha "64" "$(jq -r '.files[0].sha256 | length' "$tmp/out")"

run "$here/evidence-check.sh" "$tmp/zero.png"
check ev-zero "1" "$code"
check ev-zero-msg "zero bytes" "$(jq -r '.problems[0].problem' "$tmp/out")"

run "$here/evidence-check.sh" "$tmp/blank.png" --min-bytes 5000
check ev-small "1" "$code"

run "$here/evidence-check.sh" "$tmp/nope.png"
check ev-missing "1" "$code"

run "$here/evidence-check.sh" --before "$tmp/a.png" --after "$tmp/a-copy.png" --min-bytes 10
check ev-identical "1" "$code"
check ev-identical-flag "true" "$(jq -r '.pair.identical' "$tmp/out")"

run "$here/evidence-check.sh" --before "$tmp/a.png" --after "$tmp/b.png" --min-bytes 10
check ev-differ "0" "$code"
check ev-differ-flag "false" "$(jq -r '.pair.identical' "$tmp/out")"

run "$here/evidence-check.sh" --before "$tmp/a.png"
check ev-half-pair "2" "$code"
run "$here/evidence-check.sh"
check ev-no-args "2" "$code"

cat >"$tmp/good.md" <<'MD'
## What changed

Adds a thing.

## Risk

`low`: small. Merge policy: balanced, a person approves.

## Review guide

- **Start here:** `src/thing.ts`
- **Look hard:** `src/thing.ts:10` guard
- **Not in this change:** the follow-up

## Build

- Command: `npm test`
- CI: https://ci.example.test/run/1
- Result: green

## Proof

| Claim | Kind | Evidence |
| --- | --- | --- |
| screen changed | image | ![before](/uploads/a/before.png) ![after](/uploads/a/after.png) |
| flow works | video | ![clip](/uploads/a/clip.mp4) |
| call works | curl | 200 ok |
| row written | query | one row |
| path | diagram | below |

## Try it

1. Run the call, you should see 200

```bash
curl -sS -X POST 'http://localhost:3000/example' -H 'content-type: application/json' -d '{}'
```

```http
POST /example HTTP/1.1
Host: localhost:3000
```

```sql
select id from example where id = 'x'; -- insert is only a comment
```

## Walkthrough

```mermaid
sequenceDiagram
  A->>B: call
```
MD
echo '{"ui_changed":true,"behavior_changed":true,"backend_changed":true,"db_changed":true,"deep_change":true}' >"$tmp/full.json"

run "$here/proof-check.sh" "$tmp/good.md" "$tmp/full.json"
check pc-good "0" "$code"
check pc-counts "2" "$(jq -r '.counts.image' "$tmp/out")"

awk '/^## Proof/{skip=1} /^## Try it/{skip=0} !skip' "$tmp/good.md" >"$tmp/noproof.md"
run "$here/proof-check.sh" "$tmp/noproof.md" "$tmp/full.json"
check pc-noproof "1" "$code"
check pc-noproof-heading "true" "$(jq '.missing | index("heading:Proof") != null' "$tmp/out")"
check pc-noproof-images "true" "$(jq '.missing | index("proof:before_after_images") != null' "$tmp/out")"

echo '{"backend_changed":true}' >"$tmp/backend.json"
grep -v '^curl' "$tmp/good.md" >"$tmp/nocurl.md"
run "$here/proof-check.sh" "$tmp/nocurl.md" "$tmp/backend.json"
check pc-nocurl "1" "$code"
check pc-nocurl-item "true" "$(jq '.missing | index("proof:curl") != null' "$tmp/out")"

sed 's/^select id.*/delete from example;/' "$tmp/good.md" >"$tmp/writesql.md"
echo '{"db_changed":true}' >"$tmp/db.json"
run "$here/proof-check.sh" "$tmp/writesql.md" "$tmp/db.json"
check pc-writesql "true" "$(jq '.missing | index("proof:query_not_read_only") != null' "$tmp/out")"

sed 's/`low`/`high`/' "$tmp/good.md" >"$tmp/high.md"
run "$here/proof-check.sh" "$tmp/high.md" "$tmp/full.json"
check pc-rollback "true" "$(jq '.missing | index("risk:rollback") != null' "$tmp/out")"

printf '## Review guide\n\n- **Start here:** a\n- **Look hard:** b\n- **Not in this change:** c\n\n## Risk\n\nlow. Merge policy: x\n\n## Build\n\n`make` https://ci.example.test/1\n\nNo behavior change.\n' >"$tmp/docs.md"
echo '{"docs_only":true}' >"$tmp/docs.json"
run "$here/proof-check.sh" "$tmp/docs.md" "$tmp/docs.json"
check pc-docs "0" "$code"
sed '/No behavior change/d' "$tmp/docs.md" >"$tmp/docs2.md"
run "$here/proof-check.sh" "$tmp/docs2.md" "$tmp/docs.json"
check pc-docs-line "1" "$code"

printf '## Build\n\n- Command: `<the check>`\n' >"$tmp/tpl.md"
run "$here/proof-check.sh" "$tmp/tpl.md" "$tmp/docs.json"
check pc-template "true" "$(jq '.missing | index("template:placeholder_left") != null' "$tmp/out")"

run "$here/proof-check.sh" "$tmp/good.md"
check pc-usage "2" "$code"
run "$here/proof-check.sh" "$tmp/good.md" "$tmp/nope.json"
check pc-no-scope "2" "$code"

printf '## What changed\n\nAdds a check.\n\n## Risk\n\n`low`: docs. Merge policy: balanced.\n\n## Review guide\n\n- **Start here:** `a.js`\n- **Look hard:** `a.js:1` parse\n- **Not in this change:** UI\n\n## Build\n\n- Command: `npm test`\n- CI: https://ci.example.test/run/1\n- Result: green\n\n## Proof\n\n| Claim | Kind | Evidence |\n| --- | --- | --- |\n| aliases insert verify | script | `out/pir-args.json` |\n\n## Try it\n\n1. Run `docs/plans/x/verify.sh` and see ok\n' >"$tmp/script.md"
echo '{"kinds":["script"],"ui_changed":true}' >"$tmp/kinds.json"
run "$here/proof-check.sh" "$tmp/script.md" "$tmp/kinds.json"
check pc-kinds-script "0" "$code"
sed 's/verify.sh/verify/' "$tmp/script.md" >"$tmp/noscript.md"
run "$here/proof-check.sh" "$tmp/noscript.md" "$tmp/kinds.json"
check pc-kinds-need-sh "1" "$code"
check pc-kinds-item "true" "$(jq '.missing | index("proof:script") != null' "$tmp/out")"

printf '## Review guide\n\n- **Start here:** a.md\n- **Look hard:** a.md:1 wording\n- **Not in this change:** runtime\n\n## Risk\n\nlow. Merge policy: x\n\n## Build\n\n`make` https://ci.example.test/1\n\nNo behavior change.\n' >"$tmp/nobehave.md"
echo '{"kinds":[],"ui_changed":true}' >"$tmp/empty-kinds.json"
run "$here/proof-check.sh" "$tmp/nobehave.md" "$tmp/empty-kinds.json"
check pc-empty-kinds "0" "$code"
sed '/No behavior change/d' "$tmp/nobehave.md" >"$tmp/nobehave2.md"
run "$here/proof-check.sh" "$tmp/nobehave2.md" "$tmp/empty-kinds.json"
check pc-empty-kinds-line "1" "$code"

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
