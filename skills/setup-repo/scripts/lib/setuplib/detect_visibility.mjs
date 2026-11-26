import { run } from "./util.mjs";

const PROBE_TIMEOUT_MS = 15000;
const PROBES = {
  github: ["gh", ["gh", "repo", "view", "--json", "visibility"]],
  gitlab: ["glab", ["glab", "repo", "view", "--output", "json"]],
};

function classify(value) {
  const lowered = String(value ?? "").toLowerCase();
  if (lowered === "public") return "public";
  return ["private", "internal"].includes(lowered) ? "private" : "unknown";
}

function onPath(name) {
  const result = run("sh", ["-c", 'command -v "$1"', "sh", name]);
  return Boolean(result && result.status === 0);
}

export function probeVisibility(root, forge) {
  const probe = PROBES[forge];
  if (!probe || !onPath(probe[0])) return "unknown";
  const result = run(probe[1][0], probe[1].slice(1), { cwd: root, timeout: PROBE_TIMEOUT_MS });
  if (!result) return "unknown";
  try {
    return classify(JSON.parse(result.stdout).visibility);
  } catch {
    return "unknown";
  }
}
