import { ERROR, WARN } from "./model.mjs";

function counts(findings) {
  const errors = findings.filter((item) => item.severity === ERROR).length;
  return [errors, findings.length - errors];
}

export function toJson(findings, files) {
  const [errors, warnings] = counts(findings);
  return JSON.stringify({ findings, summary: { errors, warnings, files, skipped: false } });
}

export function skippedJson() {
  return JSON.stringify({ findings: [], summary: { errors: 0, warnings: 0, files: 0, skipped: true } });
}

export function renderHuman(findings) {
  const lines = [];
  for (const item of findings) {
    const label = item.severity === ERROR ? "ERROR" : "WARN";
    lines.push(`${item.file}:${item.line}: ${label} [${item.rule}] ${item.message}`);
    lines.push("    fix: " + item.fix_hint);
  }
  return lines.join("\n");
}

export function headline(findings) {
  const [errors, warnings] = counts(findings);
  return `clean-code: ${errors} error(s), ${warnings} warning(s) on lines you touched`;
}

export function exitCode(findings) {
  return findings.some((item) => item.severity === ERROR) ? 1 : 0;
}

export function warningsOf(findings) {
  return findings.filter((item) => item.severity === WARN);
}
