const FORGE_HOSTS = [["github", "github"], ["gitlab", "gitlab"]];
const SLUG_PATTERN = /[^/:@]+\/[^/]+?(?:\.git)?\/?$/;

function remoteUrl(repo) {
  const out = repo.git("config", "--get", "remote.origin.url");
  if (out && out.trim()) return out.trim();
  const remotes = (repo.git("remote") || "").split(/\s+/).filter(Boolean);
  if (!remotes.length) return "";
  return (repo.git("config", "--get", "remote." + remotes[0] + ".url") || "").trim();
}

function forgeOf(url) {
  if (!url) return "none";
  const lowered = url.toLowerCase();
  for (const [needle, name] of FORGE_HOSTS) if (lowered.includes(needle)) return name;
  return "other";
}

function defaultBranch(repo) {
  const ref = (repo.git("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD") || "").trim();
  if (ref) return ref.split("/").slice(1).join("/") || ref;
  for (const name of ["main", "master"]) {
    if (repo.git("show-ref", "--verify", "--quiet", "refs/remotes/origin/" + name) !== null) return name;
  }
  const current = (repo.git("symbolic-ref", "--quiet", "--short", "HEAD") || "").trim();
  return current || null;
}

function commitCount(repo) {
  const out = (repo.git("rev-list", "--count", "HEAD") || "").trim();
  return /^\d+$/.test(out) ? Number(out) : 0;
}

export function detectGit(repo) {
  if (!repo.isGit) {
    return { is_repo: false, default_branch: null, forge: "none", remote_slug_present: false, dirty: false, commit_count: 0 };
  }
  const url = remoteUrl(repo);
  const status = repo.git("status", "--porcelain") || "";
  return {
    is_repo: true, default_branch: defaultBranch(repo), forge: forgeOf(url),
    remote_slug_present: Boolean(url && SLUG_PATTERN.test(url)), dirty: Boolean(status.trim()), commit_count: commitCount(repo),
  };
}
