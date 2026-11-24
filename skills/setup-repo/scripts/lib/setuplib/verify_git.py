import os

from .verify_common import file_has, is_executable, result


def check_githooks(root, repo):
    path = (repo.git("config", "--local", "--get", "core.hooksPath") or "").strip()
    if path != ".githooks":
        return result("git-hooks", "fail", "core.hooksPath is '" + path + "', expected .githooks")
    bad = [name for name in ("pre-commit", "pre-push")
           if not is_executable(os.path.join(root, ".githooks", name)) or not file_has(os.path.join(root, ".githooks", name), "scripts/clean-code")]
    if bad:
        return result("git-hooks", "fail", ".githooks hooks missing or not calling scripts/clean-code: " + ", ".join(bad))
    return result("git-hooks", "pass", "core.hooksPath=.githooks with pre-commit and pre-push")


def check_husky(root):
    bad = [name for name in ("pre-commit", "pre-push") if not file_has(os.path.join(root, ".husky", name), "scripts/clean-code")]
    if bad:
        return result("git-hooks", "fail", ".husky hooks not calling scripts/clean-code: " + ", ".join(bad))
    return result("git-hooks", "pass", "husky hooks call scripts/clean-code")


def check_native(root, repo):
    hooks_dir = (repo.git("rev-parse", "--git-path", "hooks") or ".git/hooks").strip()
    base = hooks_dir if hooks_dir.startswith("/") else os.path.join(root, hooks_dir)
    bad = [name for name in ("pre-commit", "pre-push") if not file_has(os.path.join(base, name), "scripts/clean-code")]
    if bad:
        return result("git-hooks", "fail", "git hooks not calling scripts/clean-code: " + ", ".join(bad))
    return result("git-hooks", "pass", "native git hooks call scripts/clean-code")


def infer_hooks_via(root, repo):
    if (repo.git("config", "--local", "--get", "core.hooksPath") or "").strip() == ".githooks":
        return "githooks"
    if os.path.isdir(os.path.join(root, ".husky")):
        return "husky"
    return "native"


def check_git_hooks(root, repo, manifest):
    via = manifest["hooks_via"] if manifest else infer_hooks_via(root, repo)
    if manifest and "git-hooks" not in manifest["features"]:
        return result("git-hooks", "skip", "git-hooks not in the install record")
    if via in ("lefthook", "precommit", "none"):
        return result("git-hooks", "skip", "hooks-via " + via + ": wired by the repo's own hook setup, not verified")
    checks = {"githooks": lambda: check_githooks(root, repo), "husky": lambda: check_husky(root),
              "native": lambda: check_native(root, repo)}
    return checks[via]()


