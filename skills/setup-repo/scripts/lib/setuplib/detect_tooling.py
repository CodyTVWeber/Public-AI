import re

LINTER_RULES = (
    ("eslint", ("eslint.config.js", "eslint.config.mjs", "eslint.config.cjs", "eslint.config.ts", ".eslintrc",
                ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json", ".eslintrc.yml", ".eslintrc.yaml")),
    ("prettier", (".prettierrc", ".prettierrc.json", ".prettierrc.js", ".prettierrc.yml", "prettier.config.js")),
    ("biome", ("biome.json", "biome.jsonc")),
    ("detekt", ("detekt.yml", "config/detekt/detekt.yml", "detekt-config.yml")),
    ("ktlint", (".ktlint", ".editorconfig-ktlint")),
    ("checkstyle", ("checkstyle.xml", "config/checkstyle/checkstyle.xml")),
    ("ruff", ("ruff.toml", ".ruff.toml")),
    ("flake8", (".flake8",)),
    ("pylint", (".pylintrc", "pylintrc")),
    ("golangci", (".golangci.yml", ".golangci.yaml", ".golangci.toml")),
    ("rubocop", (".rubocop.yml",)),
    ("sonar", ("sonar-project.properties",)),
)
PYPROJECT_SECTIONS = (("ruff", "[tool.ruff"), ("black", "[tool.black"), ("pylint", "[tool.pylint"),
                      ("flake8", "[flake8]"))
PACKAGE_DEPENDENCIES = ("eslint", "prettier", "@biomejs/biome")
DEPENDENCY_NAMES = {"@biomejs/biome": "biome"}
HOOK_FILES = ((".husky", "husky"), ("lefthook.yml", "lefthook"), ("lefthook.yaml", "lefthook"),
              (".lefthook.yml", "lefthook"), (".pre-commit-config.yaml", "pre-commit"))
HOOK_NAMES = ("pre-commit", "pre-push", "commit-msg", "prepare-commit-msg", "post-commit", "post-merge")


def package_dependencies(repo):
    pkg = repo.json("package.json") if repo.has("package.json") else {}
    deps = {}
    for key in ("dependencies", "devDependencies"):
        deps.update(pkg.get(key) or {})
    return pkg, deps


BUILD_FILE_PATTERNS = ("build.gradle", "build.gradle.kts", "*/build.gradle", "*/build.gradle.kts", "pom.xml", "*/pom.xml")
BUILD_FILE_LINTERS = ("detekt", "ktlint", "checkstyle")


def build_file_linters(repo):
    found = {}
    names = [name for pattern in BUILD_FILE_PATTERNS for name in repo.match(pattern)]
    for name in names:
        text = repo.read(name)
        for linter in (item for item in BUILD_FILE_LINTERS if item in text):
            found.setdefault(linter, name)
    return found


def detect_linters(repo):
    found = {}
    for name, files in LINTER_RULES:
        hits = [item for item in files if repo.has(item)]
        if hits:
            found[name] = hits[0]
    for linter, evidence in build_file_linters(repo).items():
        found.setdefault(linter, evidence)
    pyproject = repo.read("pyproject.toml") if repo.has("pyproject.toml") else ""
    for name, section in PYPROJECT_SECTIONS:
        if section in pyproject:
            found.setdefault(name, "pyproject.toml")
    pkg, deps = package_dependencies(repo)
    for dep in PACKAGE_DEPENDENCIES:
        if dep in deps:
            found.setdefault(DEPENDENCY_NAMES.get(dep, dep), "package.json")
    if "eslintConfig" in pkg:
        found.setdefault("eslint", "package.json")
    return [{"name": name, "evidence": evidence} for name, evidence in sorted(found.items())]


OWN_MARKER = "managed-by: setup-repo"
WIRED_MARKERS = ("scripts/clean-code", "scripts/check-privacy.sh")


def classify_hook(text):
    if OWN_MARKER in text:
        return "own"
    return "wired" if any(marker in text for marker in WIRED_MARKERS) else "foreign"


def native_hooks(repo):
    hooks_dir = (repo.git("rev-parse", "--git-path", "hooks") or "").strip()
    found = {"foreign": [], "wired": [], "own": []}
    if not hooks_dir:
        return found
    base = hooks_dir if hooks_dir.startswith("/") else repo.path(hooks_dir)
    for name in HOOK_NAMES:
        text = read_hook(base, name)
        if text is not None:
            found[classify_hook(text)].append(name)
    return found


def read_hook(base, name):
    try:
        with open(base + "/" + name, errors="replace") as handle:
            return handle.read()
    except OSError:
        return None


def detect_hook_systems(repo):
    systems = []
    path = (repo.git("config", "--local", "--get", "core.hooksPath") or "").strip()
    if path:
        systems.append({"name": "core.hooksPath", "detail": path})
    if repo.has(".githooks"):
        systems.append({"name": "githooks", "detail": ".githooks"})
    for item, label in HOOK_FILES:
        if repo.has(item):
            systems.append({"name": label, "detail": item})
    _, deps = package_dependencies(repo)
    if "simple-git-hooks" in deps or repo.has(".simple-git-hooks.json"):
        systems.append({"name": "simple-git-hooks", "detail": "package.json"})
    found = native_hooks(repo)
    for kind, label in (("foreign", "native"), ("wired", "native-wired"), ("own", "native-own")):
        if found[kind]:
            systems.append({"name": label, "detail": ",".join(found[kind])})
    return systems


RULE_WINDOW = 120
MAX_RULES = (("max-params", 3), ("max-depth", 3), ("max-lines-per-function", 80))
RULE_NUMBER = re.compile(r"(?:max\s*:\s*|,\s*)(\d+)")


def loose_eslint_rules(repo, linters):
    config = next((item["evidence"] for item in linters if item["name"] == "eslint"), None)
    if not config or config == "package.json":
        return []
    text = repo.read(config)
    loose = []
    for rule, limit in MAX_RULES:
        index = text.find(rule)
        number = RULE_NUMBER.search(text[index:index + RULE_WINDOW]) if index >= 0 else None
        if number and int(number.group(1)) > limit:
            loose.append({"rule": rule, "configured": int(number.group(1)), "limit": limit, "path": config})
    return loose
