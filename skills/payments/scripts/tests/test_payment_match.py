import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "payment-match.py")
EXPECT = {"recipient": "Example Plumbing", "amount": "120.50", "purpose": "Faucet repair"}


def run(expect, actual):
    return subprocess.run([sys.executable, "-I", SCRIPT, "--expect", json.dumps(expect), "--actual", json.dumps(actual)], capture_output=True, text=True)


class PaymentMatch(unittest.TestCase):
    def test_match_numeric_amount(self):
        r = run(EXPECT, {**EXPECT, "amount": 120.5})
        self.assertEqual((r.returncode, json.loads(r.stdout)["ok"]), (0, True))

    def test_mismatch_names_only(self):
        r = run(EXPECT, {**EXPECT, "amount": "99.00", "purpose": "Other"})
        self.assertEqual(r.returncode, 1)
        self.assertEqual(json.loads(r.stdout)["mismatch"], ["amount", "purpose"])
        for secret in ("Example Plumbing", "120.50", "99.00", "Faucet", "Other"):
            self.assertNotIn(secret, r.stdout + r.stderr)

    def test_missing_field_is_mismatch(self):
        r = run(EXPECT, {"recipient": "Example Plumbing", "amount": "120.50"})
        self.assertEqual(json.loads(r.stdout)["mismatch"], ["purpose"])

    def test_recipient_exact_case(self):
        self.assertEqual(json.loads(run(EXPECT, {**EXPECT, "recipient": "example plumbing"}).stdout)["mismatch"], ["recipient"])

    def test_file_inputs(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "e.json")
            json.dump(EXPECT, open(p, "w"))
            r = subprocess.run([sys.executable, "-I", SCRIPT, "--expect", p, "--actual", p], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0)

    def test_bad_input_does_not_echo(self):
        r = subprocess.run([sys.executable, "-I", SCRIPT, "--expect", "{secret-value", "--actual", "{}"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertNotIn("secret-value", r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
