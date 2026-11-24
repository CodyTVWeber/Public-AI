#!/usr/bin/env python3
import argparse
import json
import re
import sys

DESCRIPTION = """Check a calendar event entry carries every required label.
Required: Address, Logistics, Confirmations, Official link, Source-email link, Searchable subject.
A label counts when a line starts with it followed by a colon (bullets and bold allowed).
An empty or "unknown" value passes: unknown fields stay blank and say so.
Stdout: {"ok", "missing": [...]}. Exit: 0 ok, 1 labels missing, 2 usage."""

LABELS = {
    "address": r"address",
    "logistics": r"logistics",
    "confirmations": r"confirmations?",
    "official link": r"official[ -]link",
    "source-email link": r"source[ -]e-?mail[ -]link",
    "searchable subject": r"searchable[ -]subject",
}


def main():
    parser = argparse.ArgumentParser(prog="event-entry-lint.py", description=DESCRIPTION, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file")
    args = parser.parse_args()
    try:
        with open(args.file, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        sys.stderr.write(f"cannot read: {args.file}\n")
        sys.exit(2)
    missing = [
        name
        for name, pat in LABELS.items()
        if not re.search(rf"^[\s>*+-]*\**\s*{pat}\s*(?::\s*\**|\**\s*:)", text, re.I | re.M)
    ]
    print(json.dumps({"ok": not missing, "missing": missing}))
    for name in missing:
        sys.stderr.write(f"missing: {name}\n")
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
