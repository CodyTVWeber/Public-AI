#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp

count_rule() {
  "$CQ" --all-lines "$TMPROOT/$1" 2>/dev/null | jq -r --arg r "$2" '[.findings[] | select(.rule == $r)] | length'
}

fx order.ts <<'FIX'
function helper() {
  return 1;
}
export function api() {
  return helper();
}
FIX
expect_rule "caller below its callee" order.ts function-order
assert_eq "order is a warning" "warn" "$(severity_of order.ts function-order)"
assert_eq "public position and call order both fire" "2" "$(count_rule order.ts function-order)"

fx stepped.ts <<'FIX'
export function api() {
  return helper();
}
function helper() {
  return 1;
}
FIX
expect_no_rule "caller above callee" stepped.ts function-order

fx cycle.ts <<'FIX'
function a() {
  return b();
}
function b() {
  return a();
}
FIX
expect_no_rule "a call cycle is not an order error" cycle.ts function-order

fx split.py <<'FIX'
class Left:
    def run(self):
        return 1


class Right:
    def _h(self):
        return 1
FIX
expect_no_rule "a helper in another class stays put" split.py function-order

fx box.py <<'FIX'
class Box:
    def _h(self):
        return 1

    def run(self):
        return self._h()
FIX
expect_rule "helper above the method that calls it" box.py function-order

fx tool.sh <<'FIX'
#!/usr/bin/env bash
callee() {
  echo ok
}
caller() {
  callee
}
FIX
expect_rule "shell callee above its caller" tool.sh function-order

fx tool-ok.sh <<'FIX'
#!/usr/bin/env bash
caller() {
  callee
}
callee() {
  echo ok
}
FIX
expect_no_rule "shell caller above its callee" tool-ok.sh function-order

fx api.go <<'FIX'
package main

func helper() int { return 1 }

func Api() int { return helper() }
FIX
expect_rule "unexported Go func above an exported one" api.go function-order

fx lib.rs <<'FIX'
fn helper() -> i32 { 1 }

pub fn api() -> i32 { helper() }
FIX
expect_rule "private Rust fn above a pub fn" lib.rs function-order

fx wrapped.ts <<'FIX'
export function wrapped(ok: boolean) {
  if (ok) {
    const a = 1;
    const b = a + 1;
    const c = b + 1;
    const d = c + 1;
    const e = d + 1;
    const f = e + 1;
    return f;
  }
}
FIX
expect_rule "if wrapped around the body" wrapped.ts guard-clause
assert_eq "guard clause is a warning" "warn" "$(severity_of wrapped.ts guard-clause)"

fx branched.ts <<'FIX'
export function branched(ok: boolean) {
  if (ok) {
    const a = 1;
    const b = a + 1;
    const c = b + 1;
    const d = c + 1;
    const e = d + 1;
    return e;
  }
  return 0;
}
FIX
expect_no_rule "code after the if is a guard already" branched.ts guard-clause

fx choice.ts <<'FIX'
export function choice(ok: boolean) {
  if (ok) {
    const a = 1;
    const b = a + 1;
    const c = b + 1;
    const d = c + 1;
    return d;
  } else {
    const a = 1;
    const b = a + 1;
    const c = b + 1;
    const d = c + 1;
    return d;
  }
}
FIX
expect_no_rule "if else is not a missing guard" choice.ts guard-clause

fx short.ts <<'FIX'
export function short(ok: boolean) {
  if (ok) {
    return 1;
  }
}
FIX
expect_no_rule "a short if is left alone" short.ts guard-clause

fx wrapped.py <<'FIX'
def wrapped(ok):
    if ok:
        a = 1
        b = 2
        c = 3
        d = 4
        e = 5
        f = 6
        return f
FIX
expect_rule "python if wrapped around the body" wrapped.py guard-clause

repo="$TMPROOT/debt"
make_repo "$repo"
cat > "$repo/order.ts" <<'FIX'
function helper() {
  return 1;
}
export function api() {
  return helper();
}
FIX
git -C "$repo" add -- order.ts
git -C "$repo" commit -qm order
printf 'export const base = 2;\n' > "$repo/base.ts"
debt="$(cd "$repo" && "$CQ" --changed 2>/dev/null)"
case " $debt " in
  *function-order*) bad "untouched order stays silent" "$debt" ;;
  *) ok ;;
esac
cat > "$repo/order.ts" <<'FIX'
function helper() {
  return 1;
}
export function api() {
  return helper() + 1;
}
FIX
debt="$(cd "$repo" && "$CQ" --changed 2>/dev/null)"
case " $debt " in
  *function-order*) ok ;;
  *) bad "editing the caller reports order" "$debt" ;;
esac

finish
