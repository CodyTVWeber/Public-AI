import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "event-entry-lint.py")

FULL = "\n".join([
    'Picnic',
    '',
    '- **Address:** the venue address as stated by the source',
    '- **Logistics:** park at the north lot, bring chairs',
    '- **Confirmations:** unknown',
    '- **Official link:** https://venue.example.test',
    '- **Source-email link:** https://mail.example.test/m/1',
    '- **Searchable subject:** Picnic details',
    "",
])


def lint(text):
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
        f.write(text)
    try:
        r = subprocess.run([sys.executable, "-I", SCRIPT, f.name], capture_output=True, text=True)
    finally:
        os.unlink(f.name)
    return r.returncode, json.loads(r.stdout)


class EntryLint(unittest.TestCase):
    def test_complete(self):
        self.assertEqual(lint(FULL), (0, {"ok": True, "missing": []}))

    def test_label_styles(self):
        text = "Address: x\n**Logistics**: y\n* Confirmations:\nOfficial link: z\n> Source email link: w\nSearchable subject: s\n"
        self.assertEqual(lint(text)[0], 0)

    def test_missing_listed(self):
        code, out = lint(FULL.replace("- **Logistics:** park at the north lot, bring chairs\n", "").replace("Searchable subject", "Subject"))
        self.assertEqual((code, out["missing"]), (1, ["logistics", "searchable subject"]))

    def test_label_in_prose_does_not_count(self):
        self.assertEqual(lint("Please send the address soon.\n")[0], 1)

    def test_unreadable(self):
        r = subprocess.run([sys.executable, "-I", SCRIPT, "/nonexistent.md"], capture_output=True)
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
