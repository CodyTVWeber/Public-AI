#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp

fx params4.ts <<'FIX'
export function build(a: string, b: string, c: string, d: string) {
  return a + b + c + d;
}
FIX
expect_rule "four params" params4.ts param-count
assert_eq "four params is an error" "error" "$(severity_of params4.ts param-count)"

fx params3.ts <<'FIX'
export function build(a: string, b: string, c: string) {
  return a + b + c;
}
export const opts = ({ a, b }: { a: string; b: string }) => a + b;
FIX
assert_eq "three params is a warning" "warn" "$(severity_of params3.ts param-count)"

fx params2.ts <<'FIX'
export function build(a: string, b: Map<string, number>) {
  return a + b.size;
}
FIX
expect_no_rule "generic commas are one param" params2.ts param-count

fx mutate.ts <<'FIX'
export function total(order: Order) {
  order.total = 5 + order.items.length;
  return order;
}
export function bump(count: number) {
  count += 1;
  return count;
}
export function setTotal(order: Order) {
  order.total = 9;
}
FIX
assert_eq "property assignment and compound assignment found" "2" "$("$CQ" --all-lines "$TMPROOT/mutate.ts" 2>/dev/null | jq '[.findings[] | select(.rule == "param-mutation")] | length')"

fx idiom.ts <<'FIX'
export function handler(req: Request, res: Response) {
  res.statusCode = 404;
  req.user = load();
  return res;
}
export function attach(ref: Ref, ctx: Ctx) {
  ref.current = 1;
  ctx.value = 2;
}
FIX
assert_eq "framework idioms are warnings" "warn" "$(severity_of idiom.ts param-mutation)"
assert_eq "four idiom mutations reported" "4" "$("$CQ" --all-lines "$TMPROOT/idiom.ts" 2>/dev/null | jq '[.findings[] | select(.rule == "param-mutation")] | length')"

fx plainref.ts <<'FIX'
export function relabel(ref: Ref) {
  ref.label = 1;
  return ref;
}
export function stamp(order: Order) {
  order.stamped = true;
  return order;
}
FIX
assert_eq "non-idiom mutation stays an error" "error" "$(severity_of plainref.ts param-mutation)"
assert_eq "only .current is the ref idiom" "2" "$("$CQ" --all-lines "$TMPROOT/plainref.ts" 2>/dev/null | jq '[.findings[] | select(.rule == "param-mutation" and .severity == "error")] | length')"

fx pure.ts <<'FIX'
export function total(order: Order) {
  const next = { ...order, total: order.items.length };
  if (next.total == 1) {
    return next;
  }
  return order;
}
FIX
expect_no_rule "pure function passes" pure.ts param-mutation

fx flag.ts <<'FIX'
export function render(isActive: boolean, label: string) {
  return isActive ? label : "";
}
export function size(isbn: string) {
  return isbn.length;
}
FIX
expect_rule "boolean flag param" flag.ts bool-flag-param
assert_eq "flag is a warning" "warn" "$(severity_of flag.ts bool-flag-param)"

fx magic.ts <<'FIX'
export const TIMEOUT_MS = 5000;
const retries = 3600;
export function wait(delay = 250) {
  const items = [1, 2, 3];
  return items[2] + delay + 0 + 1 + 2 - 1;
}
export function limit(x: number) {
  return x * 86400;
}
FIX
expect_rule "magic number" magic.ts magic-number
assert_eq "only the bare literal is flagged" "1" "$("$CQ" --all-lines "$TMPROOT/magic.ts" 2>/dev/null | jq '[.findings[] | select(.rule == "magic-number")] | length')"

fx tests/magic.test.ts <<'FIX'
export function limit(x: number) {
  return x * 86400;
}
FIX
expect_no_rule "magic numbers skipped in tests" tests/magic.test.ts magic-number

fx nest4.ts <<'FIX'
export function deep(a: number[]) {
  if (a) {
    for (const x of a) {
      while (x) {
        if (x > 1) {
          return x;
        }
      }
    }
  }
  return a;
}
FIX
assert_eq "four deep is an error" "error" "$(severity_of nest4.ts nesting-depth)"

fx nest3.ts <<'FIX'
export function shallow(a: number[]) {
  if (a) {
    for (const x of a) {
      if (x > 1) {
        return x;
      }
    }
  }
  return a;
}
FIX
assert_eq "three deep is a warning" "warn" "$(severity_of nest3.ts nesting-depth)"

fx guard.ts <<'FIX'
export function flat(a: number[]) {
  if (!a) {
    return a;
  }
  const first = a[0];
  const lambda = () => {
    return first;
  };
  return lambda();
}
FIX
expect_no_rule "guard clauses stay flat" guard.ts nesting-depth

long_body() { local n="$1" i; for i in $(seq 1 "$n"); do printf '  total = total + %s;\n' "$i"; done; }
{ echo 'export function long(total: number) {'; long_body 45; echo '  return total;'; echo '}'; } > "$TMPROOT/long45.ts"
{ echo 'export function long(total: number) {'; long_body 85; echo '  return total;'; echo '}'; } > "$TMPROOT/long85.ts"
assert_eq "46 logic lines warn" "warn" "$(severity_of long45.ts function-length)"
assert_eq "86 logic lines error" "error" "$(severity_of long85.ts function-length)"

fx inline.ts <<'FIX'
export function orchestrate(path: string) {
  const first = step(path);
  const second = step(first);
  const third = step(second);
  try {
    const raw = read(third);
    const parsed = parse(raw);
    log(parsed);
    return parsed;
  } catch (err) {
    log(err);
    throw err;
  }
}
FIX
expect_rule "inline try/catch in a long function" inline.ts inline-try-catch

fx dup.ts <<'FIX'
export const a = pick("shared-label");
export const b = pick("shared-label");
export const c = pick("shared-label");
export const d = pick("once-only");
FIX
expect_rule "duplicate string" dup.ts duplicate-string

fx src/service/user.ts <<'FIX'
export const user = 1;
FIX
expect_rule "layer folder" src/service/user.ts layer-folder

fx clean.ts <<'FIX'
const LIMIT = 100;
export function clamp(value: number, max = LIMIT) {
  if (value > max) {
    return max;
  }
  return value;
}
FIX
expect_clean "clean ts file" clean.ts
finish
