import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
LINT = os.path.join(HERE, "..", "draft-lint.py")
PATH_SH = os.path.join(HERE, "..", "draft-path.sh")

CONFIG = {"greeting": "Hi", "closings": ["Thanks,"], "signature": "Sender Name", "phone": "x4455"}

GOOD = "\n".join(
    [
        "**To:** Recipient",
        "**Subject:** License renewal",
        "",
        "Hi Recipient,",
        "",
        "Quick follow-up on the license renewal.",
        "",
        "1. **Seats**",
        "   - Please put the seat count in writing",
        "     - Annual plan only",
        "",
        "2. **Schedule**",
        "   - Renew the week of the 14th",
        "",
        "Thanks,",
        "Sender Name",
        "x4455",
        "",
    ]
)


class DraftLint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.config = os.path.join(cls.tmp.name, "cfg.json")
        with open(cls.config, "w") as f:
            json.dump(CONFIG, f)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def write(self, text, name="draft.md"):
        path = os.path.join(self.tmp.name, name)
        with open(path, "w") as f:
            f.write(text)
        return path

    def run_lint(self, text, *args):
        return subprocess.run([sys.executable, "-I", LINT, self.write(text), *args], capture_output=True, text=True)

    def lint(self, text, *args):
        r = self.run_lint(text, "--config", self.config, *args)
        return r.returncode, {v["rule"] for v in json.loads(r.stdout)}

    def test_clean(self):
        self.assertEqual(self.lint(GOOD), (0, set()))

    def test_banned_discussion_variants(self):
        for phrase in ("As briefly discussed", "As discussed in our earlier correspondence", "As discussed in our correspondence"):
            self.assertIn("banned_phrase", self.lint(GOOD.replace("Quick", phrase + ", quick"))[1])

    def test_banned_phrase_and_tz(self):
        code, rules = self.lint(GOOD.replace("Quick follow-up", "Thanks so much. Call at 3pm EST. Quick follow-up"))
        self.assertEqual(code, 1)
        self.assertTrue({"banned_phrase", "tz_label"} <= rules)

    def test_tz_allowed_when_elsewhere(self):
        text = GOOD.replace("the 14th", "the 14th at 3pm EST")
        self.assertIn("tz_label", self.lint(text)[1])
        self.assertNotIn("tz_label", self.lint(text, "--recipient-elsewhere")[1])

    def test_greeting_from_config(self):
        self.assertIn("greeting_mismatch", self.lint(GOOD.replace("Hi Recipient,", "Recipient,"))[1])
        self.assertIn("greeting_mismatch", self.lint(GOOD.replace("Hi Recipient,", "Hello Recipient,"))[1])

    def test_opening_length(self):
        text = GOOD.replace("Quick follow-up on the license renewal.", "One. Two. Three.")
        self.assertIn("opening_over_2_sentences", self.lint(text)[1])

    def test_emoji(self):
        self.assertIn("emoji", self.lint(GOOD.replace("Seats", "Seats \U0001F600"))[1])

    def test_fenced_lines_ignored(self):
        text = GOOD.replace("\nThanks,", "\n```\nhope you're well\n```\nThanks,")
        self.assertEqual(self.lint(text), (0, set()))

    def test_headers(self):
        self.assertIn("header_missing:subject", self.lint(GOOD.replace("**Subject:** License renewal\n", ""))[1])

    def test_closing_signature_phone(self):
        self.assertIn("closing_missing", self.lint(GOOD.replace("Thanks,", "Regards,"))[1])
        self.assertIn("phone_missing", self.lint(GOOD.replace("x4455", ""))[1])
        self.assertIn("signature_missing", self.lint(GOOD.replace("Sender Name", "Someone"))[1])

    def test_skip(self):
        self.assertEqual(self.lint(GOOD.replace("x4455", ""), "--skip", "phone")[0], 0)

    def test_closing_differs_per_config(self):
        path = os.path.join(self.tmp.name, "other.json")
        with open(path, "w") as f:
            json.dump({"closings": ["Regards,"]}, f)
        r = self.run_lint(GOOD.replace("Thanks,", "Regards,"), "--config", path)
        self.assertEqual(r.returncode, 0)
        r = self.run_lint(GOOD, "--config", path)
        self.assertIn("closing_missing", r.stdout)

    def test_output_profile_ignores_email_shape(self):
        r = self.run_lint("Done. Ship it.\n\n1. **Next**\n   - go\n", "--profile", "output")
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "[]"))
        r = self.run_lint("Please don't hesitate.\n", "--profile", "output")
        self.assertEqual({v["rule"] for v in json.loads(r.stdout)}, {"banned_phrase"})

    def test_output_profile_opening_length(self):
        r = self.run_lint("One. Two. Three.\n\n1. **Next**\n", "--profile", "output")
        self.assertIn("opening_over_2_sentences", r.stdout)

    def test_missing_config_skips_personal_checks(self):
        missing = os.path.join(self.tmp.name, "none.json")
        text = GOOD.replace("Thanks,\nSender Name\nx4455\n", "")
        r = self.run_lint(text, "--config", missing)
        self.assertEqual(r.returncode, 0)
        self.assertIn("skipped", r.stderr)

    def test_env_config(self):
        env = {**os.environ, "AI_SKILLS_EMAIL_CONFIG": self.config}
        r = subprocess.run([sys.executable, "-I", LINT, self.write(GOOD.replace("x4455", ""))], capture_output=True, text=True, env=env)
        self.assertIn("phone_missing", r.stdout)

    def test_unreadable_file(self):
        r = subprocess.run([sys.executable, "-I", LINT, os.path.join(self.tmp.name, "nope.md")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)


class DraftPath(unittest.TestCase):
    def run_sh(self, *args):
        return subprocess.run(["bash", PATH_SH, *args], capture_output=True, text=True)

    def test_path(self):
        with tempfile.TemporaryDirectory() as d:
            r = self.run_sh("--dir", d, "license renewal")
            path = json.loads(r.stdout)["path"]
            self.assertEqual(path, f"{d}/draft-license-renewal.md")
            open(path, "w").close()
            again = json.loads(self.run_sh("--dir", d, "license renewal").stdout)["path"]
            self.assertEqual(again, f"{d}/draft-license-renewal-2.md")

    def test_path_slug(self):
        with tempfile.TemporaryDirectory() as d:
            path = json.loads(self.run_sh("--dir", d, "Q3: Seats & Support!").stdout)["path"]
            self.assertEqual(path, f"{d}/draft-q3-seats-support.md")

    def test_usage(self):
        self.assertEqual(self.run_sh().returncode, 2)
        self.assertEqual(self.run_sh("--bogus", "x").returncode, 2)
        self.assertEqual(self.run_sh("!!!").returncode, 2)
        self.assertEqual(self.run_sh("--help").returncode, 0)


if __name__ == "__main__":
    unittest.main()
