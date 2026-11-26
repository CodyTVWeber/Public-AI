import fs from "node:fs";
import path from "node:path";
import { fileStep, Step, writeBytes } from "./plan_model.mjs";
import { exists } from "./util.mjs";

const GITLAB_FILE = ".gitlab/ci/ai-guardrails.yml";
const GITHUB_FILE = ".github/workflows/ai-guardrails.yml";
const ROOT_CI = ".gitlab-ci.yml";
const INCLUDE_LINE = "  - local: " + GITLAB_FILE;
const CONTROL_NOTE = "CI is the control a PR cannot silently delete: local hooks and .claude settings ship in the same diff "
  + "and can be edited out, so make these jobs required and protect the CI files with code owners";
const MANUAL_COMMANDS = 'scripts/clean-code/pre-push-gate.sh "$BASE"\nscripts/clean-code/code-quality-check.sh --changed "$BASE"\n'
  + 'scripts/clean-code/lint-docs.sh "$BASE"\n';

export { CONTROL_NOTE };

function readAsset(ctx, name) {
  return fs.readFileSync(path.join(ctx.assets, "ci", name), "utf8");
}

function gitlabStage(text) {
  const match = /^stages:\s*\n((?:[ \t]+-.*\n?)+)/m.exec(text);
  if (!match) return "test";
  const names = match[1].split(/\r\n|\r|\n/).filter((line) => line !== "").map((line) => line.trim().replace(/^-+/, "").trim());
  return names.includes("test") ? "test" : ".pre";
}

function gitlabFileText(ctx) {
  const root = ctx.dest(ROOT_CI);
  const stage = exists(root) ? gitlabStage(fs.readFileSync(root, "utf8")) : "test";
  let text = readAsset(ctx, "gitlab-ai-guardrails.yml").split("{{STAGE}}").join(stage);
  if (ctx.on("pr-template")) text += readAsset(ctx, "gitlab-pr-body-job.yml");
  return Buffer.from(text);
}

function includeBlockEnd(lines, start) {
  let end = start;
  for (let index = start + 1; index < lines.length; index++) {
    const line = lines[index];
    if (line.trim() && !/^\s/.test(line) && !line.startsWith("-")) break;
    if (line.trim()) end = index;
  }
  return end;
}

function addInclude(text) {
  const lines = text.split("\n");
  const heads = lines.map((line, i) => (/^include:\s*(#.*)?$/.test(line) ? i : -1)).filter((i) => i >= 0);
  if (!text.trim()) return "include:\n" + INCLUDE_LINE + "\n";
  if (lines.some((line) => /^include:\s*\S/.test(line)) || heads.length > 1) return null;
  if (!heads.length) return text.replace(/\n+$/, "") + "\n\ninclude:\n" + INCLUDE_LINE + "\n";
  const end = includeBlockEnd(lines, heads[0]);
  const first = lines.slice(heads[0] + 1, end + 1).find((line) => line.trim().startsWith("-"));
  if (first === undefined) return null;
  const indent = first.slice(0, first.length - first.trimStart().length);
  lines.splice(end + 1, 0, indent + "- local: " + GITLAB_FILE);
  return lines.join("\n");
}

function gitlabIncludeStep(ctx) {
  const root = ctx.dest(ROOT_CI);
  const current = exists(root) ? fs.readFileSync(root, "utf8") : null;
  if (current !== null && current.includes(GITLAB_FILE)) {
    return new Step("ci:include", "skip", ROOT_CI, "already includes the guardrails job file");
  }
  const updated = addInclude(current ?? "");
  if (updated === null) {
    return new Step("ci:include", "manual", ROOT_CI, "include: is not a simple list: add `- local: " + GITLAB_FILE + "` by hand",
      { extra: { snippet: INCLUDE_LINE + "\n" } });
  }
  return new Step("ci:include", current !== null ? "merge" : "create", ROOT_CI, "includes the guardrails job file",
    { run: () => writeBytes(root, Buffer.from(updated), false) });
}

function githubFileText(ctx) {
  let text = readAsset(ctx, "github-ai-guardrails.yml");
  if (ctx.on("pr-template")) text += readAsset(ctx, "github-pr-body-step.yml");
  return Buffer.from(text);
}

function ciProvider(ctx) {
  const forge = ctx.detected.git.forge;
  if (["gitlab", "github"].includes(forge)) return forge;
  const provider = ctx.detected.ci.provider;
  return ["gitlab", "github"].includes(provider) ? provider : null;
}

export function ciFilePath(ctx) {
  return { gitlab: GITLAB_FILE, github: GITHUB_FILE }[ciProvider(ctx)] ?? null;
}

export function ciSteps(ctx) {
  if (!ctx.on("ci")) return [];
  const provider = ciProvider(ctx);
  if (provider === null) {
    return [new Step("ci", "manual", "", "no GitLab or GitHub adapter for this repo: run these in your pipeline. " + CONTROL_NOTE,
      { extra: { snippet: MANUAL_COMMANDS } })];
  }
  if (provider === "gitlab") {
    const spec = { id: "ci", path: GITLAB_FILE, reason: "GitLab job file: mr-size, clean-code, docs-lint. " + CONTROL_NOTE };
    return [fileStep(ctx, spec, gitlabFileText(ctx)), gitlabIncludeStep(ctx)];
  }
  const spec = { id: "ci", path: GITHUB_FILE, reason: "GitHub workflow of its own, existing workflows untouched. " + CONTROL_NOTE };
  return [fileStep(ctx, spec, githubFileText(ctx))];
}
