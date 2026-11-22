#!/usr/bin/env python3
"""Upload images to a GitLab project; print {filename: markdown}. Usage: GL_TOKEN=$(glab config get token --host gitlab.com) upload-evidence.py <project-id> <png>..."""
import json
import os
import sys
import urllib.request
import uuid

HOST = "https://gitlab.com"


def upload(project_id, token, path):
    boundary = uuid.uuid4().hex
    name = os.path.basename(path)
    with open(path, "rb") as f:
        data = f.read()
    head = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\n'
        "Content-Type: image/png\r\n\r\n"
    ).encode()
    body = head + data + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        f"{HOST}/api/v4/projects/{project_id}/uploads",
        data=body,
        headers={"PRIVATE-TOKEN": token, "Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    return json.load(urllib.request.urlopen(req))["markdown"]


def main():
    project_id, paths = sys.argv[1], sys.argv[2:]
    token = os.environ["GL_TOKEN"]
    print(json.dumps({os.path.basename(p): upload(project_id, token, p) for p in paths}))


main()
