import json
import os
import sys

from .exclude import block_entries, block_needed, write_block
from .skills_sets import SKILL_FILE, SOURCE_HINT, skill_names, source_dir, valid_set

LINK_DIR = ".claude/skills"
EXCLUDE_TAG = "skills"
NO_SOURCE_EXIT = 3
USAGE = """Usage: link-skills.sh <target> [--skills-from PATH] [--skills SET] [--force] [--dry-run]

Symlinks skills from a Public-AI clone into <target>/.claude/skills/<name> (absolute-path links) and adds one
.git/info/exclude entry per link (.claude/skills/<name>), so the links stay local and uncommitted while the
team's own skills in that directory stay visible. Entries for removed links are dropped on the next run.
  --skills-from PATH  clone to link from (default: $PUBLIC_AI_DIR; no other default)
  --skills SET        core (default: write-plan, align, implement, review, watch, plan-implement-review-watch, plus support skills plan-implement-review, verify-change, monitor, review-*),
                      core+aliases (core plus the one-line aliases, apirw, apirwm and code-review), all (every skill dir with a SKILL.md), none,
                      or a comma list of skill names
  --force             replace a link that points elsewhere (a real directory is never replaced)
  --dry-run           report only
Missing names and directories without a SKILL.md are skipped with a warning.
Stdout: JSON {source, links:[{name, status}], warnings[]}; status: create, same, replace, conflict, skipped.
Exit: 0 ok, 2 usage, 3 no source clone or not a git repo"""


def link_state(dest, target, force):
    if not os.path.lexists(dest):
        return "create"
    if not os.path.islink(dest):
        return "conflict"
    if os.readlink(dest) == target:
        return "same"
    return "replace" if force else "conflict"


def plan_links(places, names, force):
    root, source = places
    links, warnings = [], []
    for name in names:
        src = os.path.join(source, "skills", name)
        if not os.path.isfile(os.path.join(src, SKILL_FILE)):
            warnings.append("skipped " + name + ": no " + SKILL_FILE + " in " + src)
            links.append({"name": name, "status": "skipped"})
            continue
        dest = os.path.join(root, LINK_DIR, name)
        links.append({"name": name, "status": link_state(dest, src, force), "src": src, "dest": dest})
    return links, warnings


def create_link(link):
    os.makedirs(os.path.dirname(link["dest"]), exist_ok=True)
    if os.path.islink(link["dest"]):
        os.unlink(link["dest"])
    os.symlink(link["src"], link["dest"])


def exclude_entries(root, links):
    wanted = {link["name"] for link in links if link["status"] in ("create", "same", "replace")}
    previous = {line[len(LINK_DIR) + 1:] for line in block_entries(root, EXCLUDE_TAG) if line.startswith(LINK_DIR + "/")}
    kept = {name for name in previous if os.path.lexists(os.path.join(root, LINK_DIR, name))}
    return [LINK_DIR + "/" + name for name in sorted(wanted | kept)]


def exclude_needed(root, links):
    return block_needed(root, EXCLUDE_TAG, exclude_entries(root, links))


def apply_links(root, links):
    for link in links:
        if link["status"] in ("create", "replace"):
            create_link(link)
    write_block(root, EXCLUDE_TAG, exclude_entries(root, links))


def public_links(links):
    return [{"name": link["name"], "status": link["status"]} for link in links]


def parse_args(argv):
    opts = {"target": None, "from": None, "set": "core", "force": False, "dry": False}
    pending = iter(argv)
    for arg in pending:
        if arg in ("--skills-from", "--skills"):
            opts["from" if arg == "--skills-from" else "set"] = next(pending, None)
        elif arg == "--force":
            opts["force"] = True
        elif arg == "--dry-run":
            opts["dry"] = True
        elif arg.startswith("-"):
            return None
        else:
            opts["target"] = arg
    valid = opts["target"] and opts["set"] and valid_set(opts["set"])
    return opts if valid else None


def main(argv):
    if "-h" in argv or "--help" in argv:
        print(USAGE)
        return 0
    opts = parse_args(argv)
    if opts is None:
        print(USAGE, file=sys.stderr)
        return 2
    skill_dir = os.path.realpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    source = source_dir(opts["from"])
    root = os.path.realpath(opts["target"])
    if source is None or not os.path.exists(os.path.join(root, ".git")):
        print("link-skills: no Public-AI clone (" + SOURCE_HINT + ") or target is not a git repo", file=sys.stderr)
        return NO_SOURCE_EXIT
    links, warnings = plan_links((root, source), skill_names(skill_dir, source, opts["set"]), opts["force"])
    if not opts["dry"]:
        apply_links(root, links)
    print(json.dumps({"source": source, "links": public_links(links), "warnings": warnings}))
    for warning in warnings:
        print("link-skills: " + warning, file=sys.stderr)
    return 0
