import json
import os
import re

MANIFEST_RELATIVE = ("assets", "skills-manifest.json")
SKILL_FILE = "SKILL.md"
SOURCE_ENV = "PUBLIC_AI_DIR"
SET_NAMES = ("core", "core+aliases", "all", "none")
NAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*$")
SOURCE_HINT = "set PUBLIC_AI_DIR to a Public-AI clone or pass --skills-from PATH"


def valid_set(value):
    if value in SET_NAMES:
        return True
    names = value.split(",")
    return all(NAME_PATTERN.match(name) for name in names)


def source_dir(explicit):
    candidate = explicit or os.environ.get(SOURCE_ENV)
    if not candidate:
        return None
    expanded = os.path.expanduser(candidate)
    return os.path.realpath(expanded) if os.path.isdir(os.path.join(expanded, "skills")) else None


def read_manifest(skill_dir):
    with open(os.path.join(skill_dir, *MANIFEST_RELATIVE)) as handle:
        return json.load(handle)


def every_skill(source):
    base = os.path.join(source, "skills")
    return sorted(name for name in os.listdir(base) if os.path.isfile(os.path.join(base, name, SKILL_FILE)))


def skill_names(skill_dir, source, name_set):
    if name_set == "none":
        return []
    if name_set == "all":
        return every_skill(source)
    if name_set in SET_NAMES:
        manifest = read_manifest(skill_dir)
        extra = manifest["aliases"] if name_set == "core+aliases" else []
        return manifest["core"] + manifest["support"] + extra
    return [name for name in name_set.split(",") if name]
