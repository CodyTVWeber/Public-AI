import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "upload-evidence.py")
SEEN = []


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        SEEN.append((self.path, self.headers["PRIVATE-TOKEN"], body))
        if b"fail.png" in body:
            self.send_response(500)
            self.end_headers()
            return
        self.send_response(201)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"markdown": "![x](/uploads/x)"}).encode())

    def log_message(self, *args):
        pass


def run(*args, env=None):
    full = {**os.environ, "GL_TOKEN": "fake-token", **(env or {})}
    return subprocess.run([sys.executable, "-I", SCRIPT, *args], capture_output=True, text=True, env=full)


class UploadEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("localhost", 0), Handler)
        cls.host = f"http://localhost:{cls.server.server_port}"
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.tmp = tempfile.TemporaryDirectory()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.tmp.cleanup()

    def make(self, name, data=b"x" * 64):
        path = os.path.join(self.tmp.name, name)
        with open(path, "wb") as f:
            f.write(data)
        return path

    def test_mime_by_extension(self):
        for name, mime in (("a.png", "image/png"), ("b.mp4", "video/mp4"), ("c.webm", "video/webm"), ("d.jpg", "image/jpeg"), ("e.gif", "image/gif"), ("f.webp", "image/webp")):
            SEEN.clear()
            r = run("42", self.make(name), "--host", self.host)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn(f"Content-Type: {mime}".encode(), SEEN[0][2])
            self.assertEqual(SEEN[0][0], "/api/v4/projects/42/uploads")
            self.assertEqual(SEEN[0][1], "fake-token")
            self.assertEqual(json.loads(r.stdout), {name: "![x](/uploads/x)"})

    def test_host_from_env(self):
        r = run("1", self.make("env.png"), env={"GL_HOST": self.host})
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_dry_run_makes_no_request(self):
        SEEN.clear()
        r = run("1", self.make("dry.mp4"), "--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        out = json.loads(r.stdout)
        self.assertTrue(out["dry_run"])
        self.assertEqual(out["files"][0]["mime"], "video/mp4")
        self.assertEqual(SEEN, [])

    def test_missing_file(self):
        r = run("1", os.path.join(self.tmp.name, "nope.png"), "--host", self.host)
        self.assertEqual(r.returncode, 2)
        self.assertIn("error", json.loads(r.stdout))

    def test_empty_file(self):
        r = run("1", self.make("empty.png", b""), "--host", self.host)
        self.assertEqual(r.returncode, 2)

    def test_bad_extension(self):
        r = run("1", self.make("note.txt"), "--host", self.host)
        self.assertEqual(r.returncode, 2)

    def test_too_large(self):
        r = run("1", self.make("big.png", b"x" * 100), "--host", self.host, "--max-bytes", "10")
        self.assertEqual(r.returncode, 2)

    def test_no_token(self):
        env = {k: v for k, v in os.environ.items() if k != "GL_TOKEN"}
        r = subprocess.run([sys.executable, "-I", SCRIPT, "1", self.make("t.png"), "--host", self.host], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 3)

    def test_upload_failure(self):
        r = run("1", self.make("fail.png"), "--host", self.host)
        self.assertEqual(r.returncode, 4)
        self.assertIn("HTTP 500", json.loads(r.stdout)["error"])

    def test_usage(self):
        self.assertEqual(run().returncode, 2)


if __name__ == "__main__":
    unittest.main()
