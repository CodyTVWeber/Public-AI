import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "dedupe-tasks.py")


def run(new, existing):
    with tempfile.TemporaryDirectory() as d:
        paths = []
        for name, data in (("n.json", new), ("e.json", existing)):
            p = os.path.join(d, name)
            json.dump(data, open(p, "w"))
            paths.append(p)
        r = subprocess.run([sys.executable, "-I", SCRIPT, *paths], capture_output=True, text=True)
    return r.returncode, json.loads(r.stdout) if r.stdout else None


class Dedupe(unittest.TestCase):
    def test_strings(self):
        code, out = run(["Call the vendor.", "Book room", "  book   ROOM!! "], ["call the vendor"])
        self.assertEqual(code, 0)
        self.assertEqual(out["new"], ["Book room"])
        self.assertEqual([d["item"] for d in out["duplicates"]], ["Call the vendor.", "  book   ROOM!! "])
        self.assertEqual(out["duplicates"][1]["match"], "Book room")

    def test_objects_keep_original(self):
        new = [{"action": "Send recap", "owner": "A"}, {"action": "Order chairs", "owner": "B"}]
        code, out = run(new, [{"title": "send recap", "id": 7}])
        self.assertEqual(out["new"], [new[1]])
        self.assertEqual(out["duplicates"][0]["match"], {"title": "send recap", "id": 7})

    def test_near_match_is_new(self):
        self.assertEqual(run(["Send the recap today"], ["Send recap"])[1]["new"], ["Send the recap today"])

    def test_bad_input(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "x.json")
            open(p, "w").write("{}")
            r = subprocess.run([sys.executable, "-I", SCRIPT, p, p], capture_output=True)
            self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
