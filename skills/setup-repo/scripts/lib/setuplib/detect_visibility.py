import json
import shutil
import subprocess

PROBE_TIMEOUT_SECONDS = 15
PUBLIC_VALUES = {"public"}
PRIVATE_VALUES = {"private", "internal"}
PROBES = {
    "github": ("gh", ["gh", "repo", "view", "--json", "visibility"]),
    "gitlab": ("glab", ["glab", "repo", "view", "--output", "json"]),
}


def classify(value):
    lowered = str(value or "").lower()
    if lowered in PUBLIC_VALUES:
        return "public"
    return "private" if lowered in PRIVATE_VALUES else "unknown"


def probe_visibility(root, forge):
    probe = PROBES.get(forge)
    if probe is None or shutil.which(probe[0]) is None:
        return "unknown"
    try:
        result = subprocess.run(probe[1], cwd=root, capture_output=True, text=True, timeout=PROBE_TIMEOUT_SECONDS)
        return classify(json.loads(result.stdout).get("visibility"))
    except (OSError, subprocess.SubprocessError, ValueError, AttributeError):
        return "unknown"
