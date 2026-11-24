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
  python3 -I - "$1" "$2" "$3" <<'PY'
import os
import struct
import sys
import zlib

path, size, seed = sys.argv[1], sys.argv[2], int(sys.argv[3])
w, h = (int(part) for part in size.split("x"))
raw = b"".join(b"\x00" + os.urandom(3 * w) if seed else b"\x00" + bytes(3 * w) for _ in range(h))


def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))


open(path, "wb").write(
    b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
)
PY
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

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
