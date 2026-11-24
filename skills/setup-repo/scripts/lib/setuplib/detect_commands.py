import json
import os
import re
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GATE_RELATIVE = ("..", "..", "..", "..", "plan-implement-review", "scripts", "regression-gate.sh")
GATE_TIMEOUT_SECONDS = 20
SCRIPT_ALIASES = {
    "lint": ("lint",),
    "test": ("test",),
    "typecheck": ("typecheck", "type-check", "check-types"),
    "build": ("build",),
}
MAKE_TARGET = r"^{}[ \t]*:"
PACKAGE_RUNNERS = (("pnpm-lock.yaml", "pnpm run"), ("yarn.lock", "yarn"), ("bun.lockb", "bun run"), ("bun.lock", "bun run"))
NO_TEST = re.compile(r"no test specified")


def package_runner(repo):
    return next((runner for lock, runner in PACKAGE_RUNNERS if repo.has(lock)), "npm run")


def from_package_json(repo):
    if not repo.has("package.json"):
        return {}
    scripts = repo.json("package.json").get("scripts") or {}
    runner = package_runner(repo)
    found = {}
    for kind, names in SCRIPT_ALIASES.items():
        name = next((n for n in names if n in scripts), None)
        if name and not (kind == "test" and NO_TEST.search(str(scripts[name]))):
            found[kind] = {"command": runner + " " + name, "source": "package.json:" + name}
    return found


def from_makefile(repo):
    if not repo.has("Makefile"):
        return {}
    text = repo.read("Makefile")
    found = {}
    for kind, names in SCRIPT_ALIASES.items():
        name = next((n for n in names if re.search(MAKE_TARGET.format(re.escape(n)), text, re.M)), None)
        if name:
            found[kind] = {"command": "make " + name, "source": "Makefile:" + name}
    return found


def python_commands(repo):
    text = repo.read("pyproject.toml") if repo.has("pyproject.toml") else ""
    ruff = "[tool.ruff" in text or repo.has("ruff.toml")
    mypy = "[tool.mypy" in text or repo.has("mypy.ini")
    pytest = "[tool.pytest" in text or repo.has("pytest.ini") or repo.has("tests")
    found = {}
    if ruff:
        found["lint"] = {"command": "ruff check .", "source": "python"}
    if mypy:
        found["typecheck"] = {"command": "mypy .", "source": "python"}
    if pytest:
        found["test"] = {"command": "pytest", "source": "python"}
    return found


def ecosystem_defaults(repo):
    found = {}
    if repo.has("pom.xml"):
        runner = "./mvnw -B" if repo.has("mvnw") else "mvn -B"
        found.update({"test": {"command": runner + " verify", "source": "pom.xml"},
                      "build": {"command": runner + " package", "source": "pom.xml"}})
    if repo.has("build.gradle") or repo.has("build.gradle.kts"):
        runner = "./gradlew" if repo.has("gradlew") else "gradle"
        found.update({"test": {"command": runner + " test", "source": "gradle"},
                      "build": {"command": runner + " build", "source": "gradle"}})
    if repo.has("go.mod"):
        found.update({"lint": {"command": "go vet ./...", "source": "go.mod"},
                      "test": {"command": "go test ./...", "source": "go.mod"},
                      "build": {"command": "go build ./...", "source": "go.mod"}})
    if repo.has("Cargo.toml"):
        found.update({"test": {"command": "cargo test", "source": "Cargo.toml"},
                      "build": {"command": "cargo build", "source": "Cargo.toml"}})
    return found


def regression_command(repo):
    gate = os.path.normpath(os.path.join(SCRIPT_DIR, *GATE_RELATIVE))
    if not os.access(gate, os.X_OK):
        return None
    try:
        result = subprocess.run([gate, repo.root, "--discover-only"], capture_output=True, text=True,
                                timeout=GATE_TIMEOUT_SECONDS)
        data = json.loads(result.stdout or "{}")
    except (OSError, subprocess.SubprocessError, ValueError):
        return None
    return data if data.get("command") else None


def detect_commands(repo):
    merged = {}
    for source in (ecosystem_defaults(repo), python_commands(repo), from_makefile(repo), from_package_json(repo)):
        merged.update(source)
    result = {kind: merged.get(kind) for kind in SCRIPT_ALIASES}
    result["regression"] = regression_command(repo)
    return result
