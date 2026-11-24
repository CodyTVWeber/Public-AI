#!/usr/bin/env python3
import argparse
import decimal
import json
import os
import sys

DESCRIPTION = """Compare an expected obligation with an actual receipt on recipient, amount, purpose.
--expect and --actual take a JSON object or a path to a JSON file, each with
recipient, amount, purpose. Strings match exactly after trimming; amounts match numerically.
Stdout: {"ok", "mismatch": [field names]}. Values are never printed.
Exit: 0 all match, 1 mismatch, 2 usage."""

FIELDS = ("recipient", "amount", "purpose")


def load(raw, flag):
    try:
        text = open(raw, encoding="utf-8").read() if os.path.isfile(raw) else raw
        data = json.loads(text)
    except (OSError, ValueError):
        sys.stderr.write(f"{flag} is not valid JSON or a readable JSON file\n")
        sys.exit(2)
    if not isinstance(data, dict):
        sys.stderr.write(f"{flag} must be a JSON object\n")
        sys.exit(2)
    return data


def same(field, a, b):
    if a is None or b is None:
        return False
    if field == "amount":
        try:
            return decimal.Decimal(str(a).replace(",", "").lstrip("$").strip()) == decimal.Decimal(str(b).replace(",", "").lstrip("$").strip())
        except decimal.InvalidOperation:
            return False
    return str(a).strip() == str(b).strip()


def main():
    parser = argparse.ArgumentParser(prog="payment-match.py", description=DESCRIPTION, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--expect", required=True)
    parser.add_argument("--actual", required=True)
    args = parser.parse_args()
    expect, actual = load(args.expect, "--expect"), load(args.actual, "--actual")
    mismatch = [f for f in FIELDS if not same(f, expect.get(f), actual.get(f))]
    print(json.dumps({"ok": not mismatch, "mismatch": mismatch}))
    if mismatch:
        sys.stderr.write("mismatch: " + ", ".join(mismatch) + "\n")
    sys.exit(1 if mismatch else 0)


if __name__ == "__main__":
    main()
