#!/usr/bin/env python3
import argparse
import json
import re
import sys

DESCRIPTION = """Split new tasks into new and duplicates against an existing task list.
NEW.json and EXISTING.json are JSON arrays of strings or objects; an object's text is the
first of action, title, text, summary, name. Matching is exact after lowercasing, dropping
punctuation, and collapsing whitespace. A repeat inside NEW counts as a duplicate of its first.
Stdout: {"new": [...], "duplicates": [{"item", "match"}]}. Exit: 0 ok, 2 usage."""

KEYS = ("action", "title", "text", "summary", "name")


def text_of(item):
    if isinstance(item, str):
        return item
    if isinstance(item, dict):
        for k in KEYS:
            if isinstance(item.get(k), str):
                return item[k]
    return json.dumps(item, sort_keys=True)


def norm(text):
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s]", " ", text.lower())).strip()


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        sys.stderr.write(f"cannot read JSON: {path}\n")
        sys.exit(2)
    if not isinstance(data, list):
        sys.stderr.write(f"not a JSON array: {path}\n")
        sys.exit(2)
    return data


def main():
    parser = argparse.ArgumentParser(prog="dedupe-tasks.py", description=DESCRIPTION, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("new")
    parser.add_argument("existing")
    args = parser.parse_args()
    seen = {norm(text_of(i)): i for i in load(args.existing)}
    fresh, dupes = [], []
    for item in load(args.new):
        key = norm(text_of(item))
        if key in seen:
            dupes.append({"item": item, "match": seen[key]})
        else:
            seen[key] = item
            fresh.append(item)
    print(json.dumps({"new": fresh, "duplicates": dupes}))


if __name__ == "__main__":
    main()
