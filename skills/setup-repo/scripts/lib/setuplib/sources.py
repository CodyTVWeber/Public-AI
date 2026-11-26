import os
import subprocess

SKILL_DIR = os.path.realpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
UNKNOWN_SHA = "unknown"
GIT_TIMEOUT_SECONDS = 20


def find_public_root():
    root = os.path.realpath(os.path.join(SKILL_DIR, "..", ".."))
    marker = os.path.join(root, "scripts", "check-privacy.sh")
    return root if os.path.isdir(os.path.join(root, "skills", "ai-risk")) and os.path.isfile(marker) else None


def source_root():
    return find_public_root() or SKILL_DIR


def source_sha(root):
    try:
        out = subprocess.run(["git", "-C", root, "rev-parse", "HEAD"], capture_output=True, text=True,
                             timeout=GIT_TIMEOUT_SECONDS)
    except (OSError, subprocess.SubprocessError):
        return UNKNOWN_SHA
    return out.stdout.strip() if out.returncode == 0 and out.stdout.strip() else UNKNOWN_SHA
