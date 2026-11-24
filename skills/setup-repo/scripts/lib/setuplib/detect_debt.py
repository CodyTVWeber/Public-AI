import os

from .detect_stacks import CODE_EXTENSIONS, extension_of

LONG_FILE_LINES = 400
DENSITY_MIN_LINES = 40
DENSITY_THRESHOLD = 0.25
MAX_FILES_SCANNED = 4000
HASH_COMMENT_EXTENSIONS = {"py", "rb", "sh", "bash"}
SKIPPED_PARTS = ("/test/", "/tests/", "/generated/", "/vendor/", "/node_modules/", "/fixtures/")
SKIPPED_SUFFIXES = (".min.js", ".d.ts", ".lock")


def is_comment(line, ext):
    stripped = line.strip()
    if ext in HASH_COMMENT_EXTENSIONS:
        return stripped.startswith("#") and not stripped.startswith("#!")
    return stripped.startswith(("//", "/*", "*"))


def scannable(name):
    padded = "/" + name
    if extension_of(name) not in CODE_EXTENSIONS or name.endswith(SKIPPED_SUFFIXES):
        return False
    return not any(part in padded for part in SKIPPED_PARTS)


def measure(repo, name):
    ext = extension_of(name)
    lines = [line for line in repo.read(name).splitlines() if line.strip()]
    long_file = len(repo.read(name).splitlines()) > LONG_FILE_LINES
    comments = sum(1 for line in lines if is_comment(line, ext))
    dense = len(lines) >= DENSITY_MIN_LINES and comments / len(lines) >= DENSITY_THRESHOLD
    return long_file, dense


def detect_debt(repo):
    long_files = dense_files = 0
    names = [name for name in repo.files if scannable(name) and os.path.isfile(repo.path(name))]
    for name in names[:MAX_FILES_SCANNED]:
        long_file, dense = measure(repo, name)
        long_files += long_file
        dense_files += dense
    return {"files_over_400_lines": long_files, "files_with_comment_density_high": dense_files,
            "files_scanned": min(len(names), MAX_FILES_SCANNED)}
