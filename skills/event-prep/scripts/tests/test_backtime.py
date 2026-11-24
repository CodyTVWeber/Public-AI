import json
import os
import subprocess
import sys
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "event-backtime.py")
BASE = ["--start", "2026-01-02T14:30", "--buffer-min", "10", "--drive-min", "25", "--load-min", "15", "--getready-min", "40"]


def run(*args):
    return subprocess.run([sys.executable, "-I", SCRIPT, *args], capture_output=True, text=True)


class Backtime(unittest.TestCase):
    def test_order_and_times(self):
        out = json.loads(run(*BASE).stdout)["schedule"]
        self.assertEqual([r["step"] for r in out], ["Get ready", "Load", "Depart", "Arrive", "Event start"])
        self.assertEqual([r["clock"] for r in out], ["13:00", "13:40", "13:55", "14:20", "14:30"])
        self.assertEqual(out[-1]["basis"], "stated")

    def test_prep_and_basis(self):
        out = json.loads(run(*BASE, "--prep-min", "10", "--stated", "buffer,drive").stdout)["schedule"]
        self.assertEqual(out[0]["step"], "Prep")
        by = {r["step"]: r["basis"] for r in out}
        self.assertEqual((by["Arrive"], by["Depart"], by["Load"]), ("stated", "stated", "recommendation"))

    def test_text_table_chronological(self):
        lines = run(*BASE, "--text").stdout.splitlines()
        self.assertTrue(lines[2].startswith("| 13:00 | Get ready"))
        self.assertTrue(lines[-1].startswith("| 14:30 | Event start"))

    def test_crosses_midnight(self):
        out = json.loads(run("--start", "2026-01-02T00:30", "--buffer-min", "10", "--drive-min", "25", "--load-min", "15", "--getready-min", "40").stdout)["schedule"]
        self.assertTrue(out[0]["time"].startswith("2026-01-01T23:"))

    def test_usage(self):
        self.assertEqual(run().returncode, 2)
        self.assertEqual(run("--start", "nonsense", *BASE[2:]).returncode, 2)
        self.assertEqual(run(*BASE, "--stated", "bogus").returncode, 2)


if __name__ == "__main__":
    unittest.main()
