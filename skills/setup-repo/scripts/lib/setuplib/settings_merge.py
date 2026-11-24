import json
import os

from .hookspec import specs_for

INVALID_EXIT = 3


def load(path):
    if not os.path.exists(path) or not os.path.getsize(path):
        return {}
    with open(path) as handle:
        return json.load(handle)


def registered(entries, command):
    return any(hook.get("command") == command for entry in entries for hook in entry.get("hooks", []))


def add_spec(data, spec):
    entries = data.setdefault("hooks", {}).setdefault(spec.event, [])
    if registered(entries, spec.command):
        return False
    group = next((entry for entry in entries if entry.get("matcher") == spec.matcher), None)
    if group is None:
        group = {"hooks": []} if spec.matcher is None else {"matcher": spec.matcher, "hooks": []}
        entries.append(group)
    hook = {"type": "command", "command": spec.command}
    if spec.timeout:
        hook["timeout"] = spec.timeout
    group["hooks"].append(hook)
    return True


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


def merge_settings(path, specs, dry_run=False):
    existed = os.path.exists(path)
    try:
        data = load(path)
    except ValueError:
        return {"status": "invalid", "missing": [spec.command for spec in specs]}
    missing = [spec.command for spec in specs if add_spec(data, spec)]
    if not missing:
        return {"status": "skip", "missing": []}
    if not dry_run:
        write(path, data)
    return {"status": "merge" if existed else "create", "missing": missing}


def main(argv):
    dry_run = "--dry-run" in argv
    args = [arg for arg in argv if arg != "--dry-run"]
    path, names = args[0], [name for name in args[1].split(",") if name]
    result = merge_settings(path, specs_for(names), dry_run)
    print(json.dumps(result))
    return INVALID_EXIT if result["status"] == "invalid" else 0
