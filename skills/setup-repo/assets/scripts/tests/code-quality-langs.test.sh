#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/cc-lib.sh"
new_tmp

fx Billing.kt <<'FIX'
package demo

/** Computes the bill. */
class Billing(private val rate: Double) {
    fun compute(a: Int, b: Int, c: Int, d: Int): Int {
        try {
            return a / 1000
        } catch (e: Exception) {
        }
    }

    fun render(enable: Boolean): String = if (enable) "on" else "off"
}
FIX
expect_rule "kotlin doc comment" Billing.kt added-comment
expect_rule "kotlin params" Billing.kt param-count
expect_rule "kotlin empty catch" Billing.kt empty-catch
expect_rule "kotlin magic number" Billing.kt magic-number
expect_rule "kotlin flag param" Billing.kt bool-flag-param

fx Clean.kt <<'FIX'
package demo

private const val RATE_LIMIT = 1000

class Clean(private val rate: Double) {
    fun scale(value: Int): Int {
        if (value > RATE_LIMIT) {
            return RATE_LIMIT
        }
        return value
    }
}
FIX
expect_clean "clean kotlin" Clean.kt

fx Runner.java <<'FIX'
public class Runner {
    private static final int LIMIT = 500;

    public int run(int a, int b, int c, int d) {
        int seconds = 86400;
        if (a > 1) {
            for (int i = 0; i < b; i++) {
                if (c > 2) {
                    while (d > 3) {
                        d--;
                    }
                }
            }
        }
        return seconds;
    }

    public void handle() {
        try { go(); } catch (Exception e) { }
    }
}
FIX
expect_rule "java params" Runner.java param-count
expect_rule "java nesting" Runner.java nesting-depth
expect_rule "java empty catch" Runner.java empty-catch
expect_rule "java magic number" Runner.java magic-number
assert_eq "java constant not flagged" "2" "$("$CQ" --all-lines "$TMPROOT/Runner.java" 2>/dev/null | jq '[.findings[] | select(.rule == "magic-number")] | length')"

fx server.go <<'FIX'
package main

func compute(a int, b int, c int, d int) int {
	// adds things
	if a > 1 {
		return 99
	}
	return 0
}

func (s *Server) Name(x int) string {
	return "x"
}
FIX
expect_rule "go params" server.go param-count
expect_rule "go comment" server.go added-comment
expect_rule "go magic number" server.go magic-number

fx build.go <<'FIX'
//go:build linux

package main

func name() string {
	return "x"
}
FIX
expect_clean "go build directive allowed" build.go

fx worker.py <<'FIX'
import os


def process(items, flag, cfg, extra):
    # explains
    """Docstring."""
    cfg["k"] = 1
    extra += 1
    for i in items:
        if i:
            while flag:
                if extra:
                    try:
                        pass
                    except Exception:
                        pass
    return os.name


def ok(a, is_ready=False):
    return a
FIX
expect_rule "python hash comment" worker.py added-comment
expect_rule "python params" worker.py param-count
expect_rule "python mutation" worker.py param-mutation
expect_rule "python nesting" worker.py nesting-depth
expect_rule "python empty except" worker.py empty-catch
expect_rule "python flag default" worker.py bool-flag-param
assert_eq "hash comment stays an error" "1" "$("$CQ" --all-lines "$TMPROOT/worker.py" 2>/dev/null | jq '[.findings[] | select(.rule == "added-comment")] | length')"
expect_rule "attached docstring is its own rule" worker.py docstring
assert_eq "attached docstring is a warning" "warn" "$(severity_of worker.py docstring)"

fx docs.py <<'FIX'
"""Module docstring."""


class Box:
    """Class docstring."""

    def size(self, items):
        """Method docstring."""
        return len(items)
FIX
expect_rule "module, class and method docstrings warn" docs.py docstring
expect_no_rule "attached docstrings are not errors" docs.py added-comment
assert_eq "three docstrings" "3" "$("$CQ" --all-lines "$TMPROOT/docs.py" 2>/dev/null | jq '[.findings[] | select(.rule == "docstring")] | length')"

fx floating.py <<'FIX'
def run(items):
    if items:
        """Explains the branch."""
        return items
    return []
FIX
expect_rule "free-floating string comment is an error" floating.py added-comment
expect_no_rule "free-floating string is not a docstring" floating.py docstring

fx tidy.py <<'FIX'
#!/usr/bin/env python3
import os

LIMIT = 100


def clamp(value, ceiling=LIMIT):
    if value > ceiling:
        return ceiling
    text = "# not a comment"
    return value if text else os.name


class Box:
    def size(self, items):
        return len(items)
FIX
expect_clean "clean python" tidy.py
finish
