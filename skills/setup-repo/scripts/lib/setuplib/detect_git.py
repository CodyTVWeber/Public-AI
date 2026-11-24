import re

FORGE_HOSTS = (("github", "github"), ("gitlab", "gitlab"))
SLUG_PATTERN = re.compile(r"[^/:@]+/[^/]+?(?:\.git)?/?$")


def remote_url(repo):
    out = repo.git("config", "--get", "remote.origin.url")
    if out and out.strip():
        return out.strip()
    remotes = (repo.git("remote") or "").split()
    if not remotes:
        return ""
    return (repo.git("config", "--get", "remote." + remotes[0] + ".url") or "").strip()


def forge_of(url):
    if not url:
        return "none"
    lowered = url.lower()
    for needle, name in FORGE_HOSTS:
        if needle in lowered:
            return name
    return "other"


def default_branch(repo):
    ref = (repo.git("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD") or "").strip()
    if ref:
        return ref.split("/", 1)[-1]
    for name in ("main", "master"):
        if repo.git("show-ref", "--verify", "--quiet", "refs/remotes/origin/" + name) is not None:
            return name
    current = (repo.git("symbolic-ref", "--quiet", "--short", "HEAD") or "").strip()
    return current or None


def commit_count(repo):
    out = (repo.git("rev-list", "--count", "HEAD") or "").strip()
    return int(out) if out.isdigit() else 0


def detect_git(repo):
    if not repo.is_git:
        return {"is_repo": False, "default_branch": None, "forge": "none", "remote_slug_present": False,
                "dirty": False, "commit_count": 0}
    url = remote_url(repo)
    status = repo.git("status", "--porcelain") or ""
    return {
        "is_repo": True,
        "default_branch": default_branch(repo),
        "forge": forge_of(url),
        "remote_slug_present": bool(url and SLUG_PATTERN.search(url)),
        "dirty": bool(status.strip()),
        "commit_count": commit_count(repo),
    }
