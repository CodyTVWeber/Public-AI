import json
import os

CORE_SCRIPTS = ("code-quality-check.sh", "check-clean-code.sh", "check-mr-size.sh", "pre-push-gate.sh",
                "claude-pre-tool-guard.sh", "post-git-check.sh", "git-scan.sh", "lint-docs.sh")


def result(check_id, status, detail):
    return {"id": check_id, "status": status, "detail": detail}


def is_executable(path):
    return os.path.isfile(path) and os.access(path, os.X_OK)


def file_has(path, needle):
    try:
        with open(path, errors="replace") as handle:
            return needle in handle.read()
    except OSError:
        return False


def load_manifest(root):
    path = os.path.join(root, ".claude", "ai-guardrails.json")
    try:
        with open(path) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None
