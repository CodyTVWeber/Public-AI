import json
import os
import subprocess
import sys

MANIFEST_RELATIVE = ("assets", "skills-manifest.json")
SKILL_FILE = "SKILL.md"
LINK_DIR = ".claude/skills"
EXCLUDE_ENTRY = ".claude/skills/"
NO_SOURCE_EXIT = 3
USAGE = """Usage: link-skills.sh <target> [--skills-from PATH] [--skills core|all|none] [--force] [--dry-run]

Symlinks skills from a Public-AI clone into <target>/.claude/skills/<name> (absolute-path links) and adds
.claude/skills/ to the target's .git/info/exclude, so the links stay local and uncommitted.
  --skills-from PATH  clone to link from (default: $PUBLIC_AI_DIR, else ~/code/Public-AI when it has skills/)
  --skills SET        core (default, listed in assets/skills-manifest.json), all (every skill dir with a SKILL.md), none
  --force             replace a link that points elsewhere (a real directory is never replaced)
  --dry-run           report only
Missing names and directories without a SKILL.md are skipped with a warning.
Stdout: JSON {source, links:[{name, status}], warnings[]}; status: create, same, replace, conflict, skipped.
Exit: 0 ok, 2 usage, 3 no source clone or not a git repo"""


def manifest_path(skill_dir):
    return os.path.join(skill_dir, *MANIFEST_RELATIVE)


def manifest_names(skill_dir, source, name_set):
    if name_set == "none":
        return []
    if name_set == "all":
        base = os.path.join(source, "skills")
        return sorted(name for name in os.listdir(base) if os.path.isfile(os.path.join(base, name, SKILL_FILE)))
    with open(manifest_path(skill_dir)) as handle:
        return json.load(handle)["core"]


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


def exclude_file(root):
    out = subprocess.run(["git", "-C", root, "rev-parse", "--git-path", "info/exclude"], capture_output=True, text=True)
    path = out.stdout.strip()
    return path if path.startswith("/") else os.path.join(root, path)


def exclude_needed(root):
    path = exclude_file(root)
    try:
        with open(path) as handle:
            return EXCLUDE_ENTRY not in handle.read().split("\n")
    except OSError:
        return True


def add_exclude(root):
    path = exclude_file(root)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    existing = open(path).read() if os.path.exists(path) else ""
    prefix = "" if not existing or existing.endswith("\n") else "\n"
    with open(path, "a") as handle:
        handle.write(prefix + EXCLUDE_ENTRY + "\n")


def apply_links(root, links):
    for link in links:
        if link["status"] in ("create", "replace"):
            create_link(link)
    if exclude_needed(root):
        add_exclude(root)


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
    valid = opts["target"] and opts["set"] in ("core", "all", "none")
    return opts if valid else None


def find_source(explicit):
    if explicit:
        expanded = os.path.expanduser(explicit)
        return os.path.realpath(expanded) if os.path.isdir(os.path.join(expanded, "skills")) else None
    for candidate in (explicit, os.environ.get("PUBLIC_AI_DIR"), os.path.expanduser("~/code/Public-AI")):
        if candidate and os.path.isdir(os.path.join(os.path.expanduser(candidate), "skills")):
            return os.path.realpath(os.path.expanduser(candidate))
    return None


def main(argv):
    if "-h" in argv or "--help" in argv:
        print(USAGE)
        return 0
    opts = parse_args(argv)
    if opts is None:
        print(USAGE, file=sys.stderr)
        return 2
    skill_dir = os.path.realpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    source = find_source(opts["from"])
    root = os.path.realpath(opts["target"])
    if source is None or not os.path.exists(os.path.join(root, ".git")):
        print("link-skills: no Public-AI clone found or target is not a git repo", file=sys.stderr)
        return NO_SOURCE_EXIT
    links, warnings = plan_links((root, source), manifest_names(skill_dir, source, opts["set"]), opts["force"])
    if not opts["dry"]:
        apply_links(root, links)
    print(json.dumps({"source": source, "links": public_links(links), "warnings": warnings}))
    for warning in warnings:
        print("link-skills: " + warning, file=sys.stderr)
    return 0
