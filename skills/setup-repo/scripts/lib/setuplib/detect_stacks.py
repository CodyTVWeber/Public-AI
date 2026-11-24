import os
from collections import Counter

LOCKFILES = (("pnpm-lock.yaml", "pnpm"), ("yarn.lock", "yarn"), ("bun.lockb", "bun"), ("bun.lock", "bun"),
             ("package-lock.json", "npm"), ("npm-shrinkwrap.json", "npm"))
MANIFESTS = (
    ("python", ("pyproject.toml", "requirements.txt", "uv.lock", "poetry.lock", "setup.py", "Pipfile")),
    ("go", ("go.mod",)),
    ("rust", ("Cargo.toml",)),
    ("maven", ("pom.xml",)),
    ("gradle", ("build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts")),
    ("ruby", ("Gemfile",)),
    ("php", ("composer.json",)),
    ("swift", ("Package.swift",)),
)
CODE_EXTENSIONS = {"js", "jsx", "mjs", "cjs", "ts", "tsx", "py", "go", "rs", "java", "kt", "kts", "rb",
                   "php", "cs", "swift", "scala", "c", "h", "cc", "cpp", "hpp"}
TOP_LANGUAGES = 8
MONOREPO_MANIFESTS = ("package.json", "pom.xml", "build.gradle", "build.gradle.kts", "go.mod",
                      "pyproject.toml", "Cargo.toml", "composer.json")
MONOREPO_MIN_DIRS = 2
PACKAGE_DEPTH = 4
WORKSPACE_FILES = (("pnpm-workspace.yaml", "pnpm-workspace"), ("turbo.json", "turbo"), ("nx.json", "nx"),
                   ("lerna.json", "lerna"))


def extension_of(name):
    return os.path.splitext(name)[1].lstrip(".").lower()


def language_counts(repo):
    counts = Counter(extension_of(name) for name in repo.files if extension_of(name))
    return [{"ext": ext, "files": count} for ext, count in counts.most_common(TOP_LANGUAGES)]


def node_stack(repo):
    if not repo.has("package.json"):
        return None
    evidence = ["package.json"]
    manager = next((tool for lock, tool in LOCKFILES if repo.has(lock)), None)
    evidence.extend(lock for lock, _ in LOCKFILES if repo.has(lock))
    return {"name": "node", "evidence": evidence, "package_manager": manager}


def manifest_stacks(repo):
    stacks = []
    for name, manifests in MANIFESTS:
        evidence = [item for item in manifests if repo.has(item)]
        if evidence:
            stacks.append({"name": name, "evidence": evidence})
    csproj = repo.match("*.csproj") + repo.match("*/*.csproj") + repo.match("*.sln")
    if csproj:
        stacks.append({"name": "dotnet", "evidence": csproj[:3]})
    return stacks


def typescript_stack(repo):
    configs = repo.named("tsconfig.json")
    return {"name": "typescript", "evidence": configs[:3]} if configs else None


def shell_only(repo, stacks):
    if stacks:
        return None
    scripts = [name for name in repo.files if extension_of(name) in ("sh", "bash")]
    code = [name for name in repo.files if extension_of(name) in CODE_EXTENSIONS]
    return {"name": "shell", "evidence": scripts[:3]} if scripts and not code else None


def detect_stacks(repo):
    stacks = [item for item in (node_stack(repo), typescript_stack(repo)) if item]
    stacks += manifest_stacks(repo)
    jvm_langs = {extension_of(name) for name in repo.files if extension_of(name) in ("kt", "kts", "java")}
    for stack in stacks:
        if stack["name"] in ("maven", "gradle"):
            stack["languages"] = sorted(jvm_langs)
    shell = shell_only(repo, stacks)
    return stacks + ([shell] if shell else [])


def package_dirs(repo):
    dirs = set()
    for manifest in MONOREPO_MANIFESTS:
        for found in repo.named(manifest, PACKAGE_DEPTH):
            dirs.add(os.path.dirname(found) or ".")
    return sorted(dirs)


def detect_monorepo(repo):
    markers = []
    pkg = repo.json("package.json") if repo.has("package.json") else {}
    if pkg.get("workspaces"):
        markers.append("workspaces")
    markers += [label for name, label in WORKSPACE_FILES if repo.has(name)]
    dirs = package_dirs(repo)
    if len(dirs) >= MONOREPO_MIN_DIRS:
        markers.append("multiple-manifests")
    return {"is_monorepo": bool(markers), "markers": markers, "package_dirs": dirs if markers else []}
