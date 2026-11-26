import json
import os
import subprocess

INSTALL_TIMEOUT_SECONDS = 120


def overwrite_flags(ctx):
    return [flag for path in sorted(ctx.upgrade_paths) for flag in ("--overwrite", path)]


def run_install(ctx, flags):
    command = [os.path.join(ctx.skill_dir, "scripts", "install.sh"), ctx.root] + flags
    result = subprocess.run(command, capture_output=True, text=True, timeout=INSTALL_TIMEOUT_SECONDS)
    if result.returncode != 0:
        raise RuntimeError("install.sh failed: " + result.stderr.strip()[-300:])
    return json.loads(result.stdout)


def note_installed(ctx, report):
    for item in report["files"]:
        if item["status"] in ("create", "overwrite", "same"):
            ctx.installed[item["path"]] = item["src"]
