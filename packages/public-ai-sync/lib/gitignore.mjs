import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const MARKER = "# public-ai-sync";

export function ensureGitignore(root, targetRel) {
  const file = join(root, ".gitignore");
  const line = ignoreLine(targetRel);
  const prev = existsSync(file) ? readFileSync(file, "utf8") : "";
  if (alreadyListed(prev, line)) return false;
  const pad = prev === "" || prev.endsWith("\n") ? "" : "\n";
  writeFileSync(file, `${prev}${pad}${MARKER}\n${line}\n`);
  return true;
}

export function ignoreLine(targetRel) {
  return targetRel.endsWith("/") ? targetRel : `${targetRel}/`;
}

function alreadyListed(text, line) {
  const bare = line.replace(/\/$/, "");
  return text.split(/\r?\n/).some((row) => {
    const trimmed = row.trim();
    return trimmed === line || trimmed === bare;
  });
}
