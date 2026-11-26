import { makeFinding } from "./catalog.mjs";
import { WARN } from "./model.mjs";

const MIN_FUNCTION_LOGIC = 10;
const MIN_TRY_LOGIC = 5;
const FOLLOWERS = new Set(["catch", "finally"]);
const VERDICT = ["inline-try-catch", WARN];

function tryGroups(blocks, func) {
  const own = blocks.filter((block) => block.owner === func).sort((a, b) => a.start - b.start);
  const groups = [];
  for (const block of own) {
    const last = groups[groups.length - 1];
    if (block.kind === "try") groups.push([block]);
    else if (FOLLOWERS.has(block.kind) && last && block.start <= last[last.length - 1].end + 1) last.push(block);
  }
  return groups;
}

function logicBetween(masked, start, end) {
  let total = 0;
  for (let number = start; number <= end; number++) if (masked[number].trim()) total += 1;
  return total;
}

export function tryFindings(ctx, func) {
  if (func.logic <= MIN_FUNCTION_LOGIC) return [];
  const findings = [];
  for (const group of tryGroups(ctx.src.structure.blocks, func)) {
    const start = group[0].start;
    const end = group[group.length - 1].end;
    const size = logicBetween(ctx.src.masked, start, end);
    if (size < MIN_TRY_LOGIC || !ctx.change.touches(start, end)) continue;
    const message = `${func.name}() hosts an inline try/catch of ${size} lines`;
    findings.push(makeFinding([ctx.src.path, start], VERDICT, message));
  }
  return findings;
}
