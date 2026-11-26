#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: slices-check.sh SLICES.json [--max-slices N]
Input: {"slices":[{"name":"a","paths":["src/a/**","docs/a.md"]}, ...]}
Checks: names match [a-z0-9]+(-[a-z0-9]+)* and are unique; count <= N (--max-slices, env
PIR_MAX_SLICES, default 4); every slice has at least one path; paths are relative, no "..".
Disjointness, per pair of paths from different slices:
  literal prefix = the path up to its first of * ? [ {; a path without them is an exact path
  exact vs exact          overlap when equal
  exact vs pattern        overlap when the exact path starts with the pattern's prefix, or the
                          pattern's prefix starts with the exact path plus "/"
  pattern vs pattern      overlap when either prefix starts with the other (conservative)
  a trailing "/" makes a directory pattern: "src/a/" is the same as "src/a/**"
stdout: {ok, errors:[string], overlaps:[{a, b, pattern}]}; pattern is the pair "pathA | pathB"
Exit: 0 ok, 1 invalid or overlapping, 2 usage, 3 unreadable input
USAGE
}

file="" max=${PIR_MAX_SLICES:-4}

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --max-slices) [ $# -ge 2 ] || { usage >&2; exit 2; }; max=$2; shift 2 ;;
    -*) usage >&2; exit 2 ;;
    *) [ -z "$file" ] || { usage >&2; exit 2; }; file=$1; shift ;;
  esac
done
[ -n "$file" ] || { usage >&2; exit 2; }
case "$max" in '' | *[!0-9]*) echo "max slices must be an integer" >&2; exit 2 ;; esac
[ -f "$file" ] || { echo "no such file: $file" >&2; exit 3 ; }

python3 -I - "$file" "$max" <<'PY'
import json
import re
import sys

NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
GLOB_CHARS = "*?[{"


def load(path):
    try:
        with open(path) as handle:
            doc = json.load(handle)
    except (OSError, ValueError) as err:
        print(f"unreadable input: {err}", file=sys.stderr)
        sys.exit(3)
    slices = doc.get("slices") if isinstance(doc, dict) else None
    if not isinstance(slices, list):
        print('input needs {"slices": [...]}', file=sys.stderr)
        sys.exit(3)
    return slices


def literal_prefix(path):
    for index, char in enumerate(path):
        if char in GLOB_CHARS:
            return path[:index], True
    if path.endswith("/"):
        return path, True
    return path, False


def normalize(path):
    return path[2:] if path.startswith("./") else path


def overlaps(left, right):
    lp, lg = literal_prefix(left)
    rp, rg = literal_prefix(right)
    if not lg and not rg:
        return lp == rp
    if lg and rg:
        return lp.startswith(rp) or rp.startswith(lp)
    exact, pat = (lp, rp) if rg else (rp, lp)
    return exact.startswith(pat) or pat.startswith(exact + "/")


def slice_errors(slices, max_slices):
    errors = []
    seen = set()
    if len(slices) > max_slices:
        errors.append(f"{len(slices)} slices exceeds max {max_slices}")
    for item in slices:
        name = item.get("name") if isinstance(item, dict) else None
        paths = item.get("paths") if isinstance(item, dict) else None
        if not isinstance(name, str) or not NAME.match(name):
            errors.append(f"invalid slice name: {name!r}")
        elif name in seen:
            errors.append(f"duplicate slice name: {name}")
        seen.add(name)
        errors.extend(path_errors(name, paths))
    return errors


def path_errors(name, paths):
    if not isinstance(paths, list) or not paths:
        return [f"slice {name}: paths is empty"]
    errors = []
    for path in paths:
        bad = not isinstance(path, str) or not path or path.startswith("/") or ".." in path.split("/")
        if bad:
            errors.append(f"slice {name}: invalid path {path!r}")
    return errors


def find_overlaps(slices):
    found = []
    valid = [s for s in slices if isinstance(s, dict) and isinstance(s.get("paths"), list)]
    for i, left in enumerate(valid):
        for right in valid[i + 1:]:
            found.extend(pair_overlaps(left, right))
    return found


def pair_overlaps(left, right):
    found = []
    for lpath in left["paths"]:
        for rpath in right["paths"]:
            if isinstance(lpath, str) and isinstance(rpath, str) and overlaps(normalize(lpath), normalize(rpath)):
                found.append({"a": left.get("name"), "b": right.get("name"), "pattern": f"{lpath} | {rpath}"})
    return found


def main():
    slices = load(sys.argv[1])
    errors = slice_errors(slices, int(sys.argv[2]))
    found = find_overlaps(slices)
    ok = not errors and not found
    print(json.dumps({"ok": ok, "errors": errors, "overlaps": found}, separators=(",", ":")))
    sys.exit(0 if ok else 1)


main()
PY
