import { existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const MARKER = "# public-ai-sync";

export function ensureGitignore(root, rels) {
  const file = join(root, ".gitignore");
  const prev = existsSync(file) ? readFileSync(file, "utf8") : "";
  const missing = [];
  for (const rel of rels) {
    const line = ignoreLine(root, rel);
    if (alreadyListed(prev, line) || missing.includes(line)) continue;
    missing.push(line);
  }
  if (missing.length === 0) return false;
  const pad = prev === "" || prev.endsWith("\n") ? "" : "\n";
  const header = prev.includes(MARKER) ? "" : `${MARKER}\n`;
  writeFileSync(file, `${prev}${pad}${header}${missing.join("\n")}\n`);
  return true;
}

export function ignoreLine(root, rel) {
  const normalized = String(rel).replaceAll("\\", "/").replace(/\/$/, "");
  if (isExistingFile(join(root, normalized))) return normalized;
  return `${normalized}/`;
}

function alreadyListed(text, line) {
  const bare = line.replace(/\/$/, "");
  return text.split(/\r?\n/).some((row) => {
    const trimmed = row.trim();
    return trimmed === line || trimmed === bare;
  });
}

function isExistingFile(path) {
  try {
    return statSync(path).isFile();
  } catch (err) {
    return missingPath(err);
  }
}

function missingPath(_err) {
  return false;
}
