import path from "node:path";
import { buildSource } from "./analysis.mjs";
import { isGeneratedPath } from "./languages.mjs";
import { checkComments } from "./rules_comments.mjs";
import { duplicateFindings, layerFindings, sizeFindings } from "./rules_file.mjs";
import { checkFunctions } from "./rules_functions.mjs";
import { emptyCatchFindings, magicFindings } from "./rules_lines.mjs";

const CHECKS = [checkComments, emptyCatchFindings, checkFunctions, magicFindings, sizeFindings, layerFindings, duplicateFindings];

function analyzeTarget(target, config) {
  if (isGeneratedPath(target.path)) return [];
  const source = buildSource(target.path, target.text);
  if (source === null) return [];
  const ctx = { src: source, change: target.change, limits: config.limits };
  const extension = path.extname(target.path).replace(/^\.+/, "").toLowerCase();
  return CHECKS.flatMap((check) => check(ctx)).filter((item) => !config.isDisabled(item.rule, extension));
}

function compare(left, right) {
  if (left.file !== right.file) return left.file < right.file ? -1 : 1;
  if (left.line !== right.line) return left.line - right.line;
  if (left.rule === right.rule) return 0;
  return left.rule < right.rule ? -1 : 1;
}

export function analyzeAll(targets, config) {
  return targets.flatMap((target) => analyzeTarget(target, config)).sort(compare);
}
