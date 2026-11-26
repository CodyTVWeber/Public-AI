import path from "node:path";
import { MARKER_BEGIN, MARKER_END, renderSection } from "./doc_render.mjs";
import { Step, writeBytes } from "./plan_model.mjs";
import { buildRecord, recordPath } from "./record.mjs";
import { localDocStep } from "./steps_local.mjs";
import { readText, splitlines } from "./util.mjs";

const POINTER_MAX_LINES = 3;
const POINTER_TEXT = "@AGENTS.md\n";
const escapeRegex = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const SECTION_PATTERN = new RegExp(escapeRegex(MARKER_BEGIN) + ".*?" + escapeRegex(MARKER_END) + "\\n?", "s");

function isPointer(text) {
  const lines = splitlines(text ?? "").filter((line) => line.trim());
  return lines.some((line) => line.trim() === "@AGENTS.md") && lines.length <= POINTER_MAX_LINES;
}

const VENDOR_POINTERS = [
  ["CLAUDE.md", "agents-doc:pointer"],
  ["GEMINI.md", "agents-doc:gemini"],
];

function pickDoc(ctx) {
  const agents = readText(ctx.dest("AGENTS.md"));
  const claude = readText(ctx.dest("CLAUDE.md"));
  if (agents !== null) return ["AGENTS.md", agents];
  if (claude !== null && !isPointer(claude)) return ["CLAUDE.md", claude];
  return ["AGENTS.md", null];
}

function pointerSteps(ctx) {
  const steps = [];
  for (const [name, id] of VENDOR_POINTERS) {
    if (readText(ctx.dest(name)) !== null) continue;
    steps.push(new Step(id, "create", name, "pointer to AGENTS.md; rules live in AGENTS.md",
      { run: () => writeBytes(ctx.dest(name), Buffer.from(POINTER_TEXT), false) }));
  }
  return steps;
}

function mergeSection(current, section) {
  if (current === null) return "# AGENTS.md\n\n" + section;
  if (SECTION_PATTERN.test(current)) return current.replace(SECTION_PATTERN, () => section);
  return current.replace(/\n+$/, "") + "\n\n" + section;
}

export function docSteps(ctx) {
  if (!ctx.on("agents-doc")) return [];
  if (ctx.local) return [localDocStep(ctx, renderSection(ctx))];
  const [name, current] = pickDoc(ctx);
  const updated = mergeSection(current, renderSection(ctx));
  const steps = [];
  if (updated === current) steps.push(new Step("agents-doc", "skip", name, "AI guardrails section is current"));
  else {
    const fresh = current === null || !current.includes(MARKER_BEGIN);
    steps.push(new Step("agents-doc", current === null ? "create" : "merge", name,
      fresh ? "adds the AI guardrails section" : "refreshes the AI guardrails section",
      { run: () => writeBytes(ctx.dest(name), Buffer.from(updated), false) }));
  }
  if (name === "AGENTS.md") steps.push(...pointerSteps(ctx));
  return steps;
}

export function manifestStep(ctx) {
  const text = JSON.stringify(buildRecord(ctx), null, 2) + "\n";
  const dest = recordPath(ctx.root, ctx.local);
  const shown = dest.startsWith(ctx.root) ? path.relative(ctx.root, dest) : dest;
  const current = readText(dest);
  if (current === text) return new Step("manifest", "skip", shown, "install record is current");
  return new Step("manifest", current === null ? "create" : "merge", shown,
    "records profile, features, source commit and file hashes for verify-repo.sh",
    { run: () => writeBytes(dest, Buffer.from(text), false) });
}
