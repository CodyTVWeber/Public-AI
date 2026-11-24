#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
import uuid

MIME = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".mp4": "video/mp4",
    ".webm": "video/webm",
}

DESCRIPTION = """Upload evidence files to a GitLab project and print {filename: markdown} as JSON.

Token: GL_TOKEN (for example GL_TOKEN=$(glab config get token --host <host>)).
Host: --host, else $GL_HOST, else the host of the origin git remote.
Types: png jpg jpeg gif webp mp4 webm.
Exit: 0 ok, 2 usage or bad input, 3 missing token or host, 4 upload failure.
On failure stdout carries {"error": ..., "file": ...}; details go to stderr."""


def fail(code, message, path=None):
    sys.stderr.write(message + "\n")
    print(json.dumps({"error": message, "file": path}))
    sys.exit(code)


def host_from_remote():
    try:
        url = subprocess.run(
            ["git", "config", "--get", "remote.origin.url"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    match = re.match(r"^(?:[a-z+]+://)?(?:[^@/]+@)?([^:/]+)", url)
    return match.group(1) if match else None


def normalize_host(host):
    return host if "://" in host else f"https://{host}"


def check_file(path, max_bytes):
    ext = os.path.splitext(path)[1].lower()
    if ext not in MIME:
        fail(2, f"unsupported extension: {ext or '(none)'}", path)
    if not os.path.isfile(path):
        fail(2, "file not found", path)
    size = os.path.getsize(path)
    if size == 0:
        fail(2, "file is empty", path)
    if size > max_bytes:
        fail(2, f"file is {size} bytes, over the {max_bytes} byte limit", path)
    return MIME[ext], size


def upload(project, token, item):
    host, project_id = project
    path, mime = item
    boundary = uuid.uuid4().hex
    name = os.path.basename(path).replace('"', "_")
    with open(path, "rb") as f:
        data = f.read()
    head = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\n'
        f"Content-Type: {mime}\r\n\r\n"
    ).encode()
    body = head + data + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        f"{host}/api/v4/projects/{project_id}/uploads",
        data=body,
        headers={"PRIVATE-TOKEN": token, "Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.load(resp)["markdown"]
    except urllib.error.HTTPError as e:
        fail(4, f"upload failed: HTTP {e.code}", path)
    except (urllib.error.URLError, OSError, KeyError, ValueError) as e:
        fail(4, f"upload failed: {type(e).__name__}", path)


def main():
    parser = argparse.ArgumentParser(
        prog="upload-evidence.py",
        description=DESCRIPTION,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("project_id")
    parser.add_argument("files", nargs="+")
    parser.add_argument("--host", default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--max-bytes", type=int, default=100 * 1024 * 1024)
    args = parser.parse_args()

    checked = [(p, *check_file(p, args.max_bytes)) for p in args.files]

    if args.dry_run:
        print(
            json.dumps(
                {
                    "dry_run": True,
                    "files": [
                        {"file": os.path.basename(p), "mime": mime, "bytes": size}
                        for p, mime, size in checked
                    ],
                }
            )
        )
        return

    host = args.host or os.environ.get("GL_HOST") or host_from_remote()
    if not host:
        fail(3, "no host: pass --host, set GL_HOST, or run inside a repo with an origin remote")
    token = os.environ.get("GL_TOKEN")
    if not token:
        fail(3, "GL_TOKEN is not set")

    host = normalize_host(host).rstrip("/")
    print(json.dumps({os.path.basename(p): upload((host, args.project_id), token, (p, mime)) for p, mime, _ in checked}))


if __name__ == "__main__":
    main()
