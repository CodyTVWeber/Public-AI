import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
DATES = os.path.join(HERE, "..", "weekend-dates.py")
SHEET = os.path.join(HERE, "..", "sheet-check.sh")


def make_pdf(path, **options):
    pages = options.get("pages", 1)
    size = options.get("size", (612, 792))
    text = options.get("text", "Weekend list")
    objs = {}
    kids = " ".join(f"{3 + i * 2} 0 R" for i in range(pages))
    objs[1] = "<< /Type /Catalog /Pages 2 0 R >>"
    objs[2] = f"<< /Type /Pages /Kids [{kids}] /Count {pages} >>"
    font = 3 + pages * 2
    for i in range(pages):
        objs[3 + i * 2] = f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {size[0]} {size[1]}] /Contents {4 + i * 2} 0 R /Resources << /Font << /F1 {font} 0 R >> >> >>"
        stream = f"BT /F1 12 Tf 72 700 Td ({text}) Tj ET"
        objs[4 + i * 2] = f"<< /Length {len(stream)} >>\nstream\n{stream}\nendstream"
    objs[font] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    out = b"%PDF-1.4\n"
    offsets = {}
    for n in sorted(objs):
        offsets[n] = len(out)
        out += f"{n} 0 obj\n{objs[n]}\nendobj\n".encode()
    xref = len(out)
    out += f"xref\n0 {len(objs) + 1}\n0000000000 65535 f \n".encode()
    for n in sorted(objs):
        out += f"{offsets[n]:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    with open(path, "wb") as f:
        f.write(out)


class WeekendDates(unittest.TestCase):
    def run_dates(self, day):
        r = subprocess.run([sys.executable, "-I", DATES, "--today", day], capture_output=True, text=True)
        return r.returncode, json.loads(r.stdout) if r.stdout else None

    def test_each_weekday(self):
        expect = {"2024-11-25": "2024-11-30", "2024-11-29": "2024-11-30", "2024-11-30": "2024-11-30", "2024-12-01": "2024-11-30"}
        for today, sat in expect.items():
            code, out = self.run_dates(today)
            self.assertEqual((code, out["saturday"]), (0, sat))
            self.assertEqual(out["sunday"], "2024-12-01")

    def test_bad_date(self):
        self.assertEqual(self.run_dates("tomorrow")[0], 2)


class SheetCheck(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def pdf(self, name, **kw):
        path = os.path.join(self.tmp.name, name)
        make_pdf(path, **kw)
        return path

    def check(self, path, env=None):
        r = subprocess.run(["bash", SHEET, path], capture_output=True, text=True, env=env)
        return r.returncode, json.loads(r.stdout), r.stderr

    def test_ok(self):
        code, out, _ = self.check(self.pdf("ok.pdf"))
        self.assertEqual((code, out["pages"]), (0, 1))

    def test_too_many_pages(self):
        self.assertEqual(self.check(self.pdf("three.pdf", pages=3))[0], 1)

    def test_not_letter(self):
        code, out, _ = self.check(self.pdf("a4.pdf", size=(595, 842)))
        self.assertEqual(code, 1)
        self.assertIn("size", out["failures"][0])

    def test_url_in_text(self):
        code, out, _ = self.check(self.pdf("url.pdf", text="see https://example.test/page"))
        self.assertEqual(code, 1)
        self.assertEqual(out["urls"], ["https://example.test/page"])

    def test_fallback_without_poppler(self):
        bindir = os.path.join(self.tmp.name, "bin")
        os.makedirs(bindir, exist_ok=True)
        for tool in ("jq", "python3", "awk", "grep", "tr", "cat", "env", "printf", "dirname"):
            found = shutil.which(tool)
            if found and not os.path.exists(os.path.join(bindir, tool)):
                os.symlink(found, os.path.join(bindir, tool))
        env = {"PATH": bindir, "HOME": self.tmp.name}
        bash = shutil.which("bash")
        r = subprocess.run([bash, SHEET, self.pdf("fb.pdf")], capture_output=True, text=True, env=env)
        out = json.loads(r.stdout)
        self.assertEqual((r.returncode, out["pages"]), (0, 1))
        self.assertIn("urls", out["skipped"])
        self.assertIn("warning", r.stderr)
        r = subprocess.run([bash, SHEET, self.pdf("fb3.pdf", pages=3)], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 1)

    def test_usage(self):
        self.assertEqual(subprocess.run(["bash", SHEET], capture_output=True).returncode, 2)
        self.assertEqual(subprocess.run(["bash", SHEET, "/nonexistent.pdf"], capture_output=True).returncode, 2)


if __name__ == "__main__":
    unittest.main()
