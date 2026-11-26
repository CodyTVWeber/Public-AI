import path from "node:path";
import { specsFor } from "./hookspec.mjs";
import { copyTreeFiles, Step } from "./plan_model.mjs";
import { mergeSettings } from "./settings_merge.mjs";
import { copySteps } from "./steps_copy.mjs";
import { isDir } from "./util.mjs";

const CLONE_HINT = "no Public-AI clone beside this skill: copy the files by hand or run bootstrap from a clone";
const PATTERNS_HINT = "create <git-dir>/info/privacy-patterns (untracked, one extended regex per line: employer names, internal "
  + "hostnames); a missing file warns, and blocks with scripts/check-privacy.sh --strict or PRIVACY_REQUIRE_PATTERNS=1";
const PRIVACY_REASON = "generic privacy gate; local patterns come from <git-dir>/info/privacy-patterns";
const GUARD_REASONS = {
  "approval-gate": "asks before every git commit and push, denies hook bypasses (for human-gated repos)",
  "research-ref": "reports how far the checkout is behind the default branch",
};

const source = (ctx, rel) => (ctx.publicRoot ? path.join(ctx.publicRoot, rel) : null);
const missingClone = (id) => [new Step(id, "manual", "", CLONE_HINT)];

function settingsStep(ctx, spec, groups) {
  const [id, reason] = spec;
  const rel = ctx.settingsRel;
  const file = ctx.dest(rel);
  const outcome = mergeSettings(file, specsFor(groups), true);
  if (outcome.status === "invalid") return new Step(id, "manual", rel, rel + " is not valid JSON: add the " + groups.join(", ") + " hooks by hand");
  if (outcome.status === "skip") return new Step(id, "skip", rel, "hooks already registered");
  return new Step(id, outcome.status, rel, reason, { run: () => mergeSettings(file, specsFor(groups)) });
}

export function claudeHookSteps(ctx) {
  const steps = [];
  if (ctx.on("claude-hooks")) {
    steps.push(settingsStep(ctx, ["claude-hooks", "PreToolUse size guard, PostToolUse docs lint and analyzer, Stop analyzer"],
      ["guard", "docs-lint", "analyzer", "stop"]));
  }
  if (ctx.on("post-git-hook")) {
    steps.push(settingsStep(ctx, ["post-git-hook", "PostToolUse(Bash) check after git commit, push, merge and pull"], ["post-git"]));
  }
  return steps;
}

const guardSpec = (ctx, id, name) => ({ id, path: "scripts/guard/" + name, src: source(ctx, "scripts/guard/" + name), reason: GUARD_REASONS[id] });

function approvalGateSteps(ctx) {
  if (!ctx.on("approval-gate")) return [];
  if (!ctx.publicRoot) return missingClone("approval-gate");
  const spec = guardSpec(ctx, "approval-gate", "git-approval-guard.sh");
  return [...copySteps(ctx, [spec]), settingsStep(ctx, ["approval-gate-hook", "PreToolUse(Bash) approval gate"], ["approval-gate"])];
}

function researchRefSteps(ctx) {
  if (!ctx.on("research-ref")) return [];
  if (!ctx.publicRoot) return missingClone("research-ref");
  const spec = guardSpec(ctx, "research-ref", "research-ref.sh");
  return [...copySteps(ctx, [spec]),
    settingsStep(ctx, ["research-ref-hook", "SessionStart hook speaks up when the checkout is behind"], ["research-ref"])];
}

function privacySteps(ctx) {
  if (!ctx.on("privacy")) return [];
  if (!ctx.publicRoot) return missingClone("privacy");
  const specs = ["check-privacy.sh", "install-hooks.sh"].map((name) => ({
    id: "privacy:" + name, path: "scripts/" + name, src: source(ctx, "scripts/" + name), reason: PRIVACY_REASON }));
  return [...copySteps(ctx, specs), new Step("privacy:patterns", "manual", "scripts/check-privacy.sh", PATTERNS_HINT)];
}

function aiRiskSteps(ctx) {
  if (!ctx.on("ai-risk")) return [];
  const base = source(ctx, "skills/ai-risk");
  if (!base || !isDir(base)) return missingClone("ai-risk");
  const specs = copyTreeFiles(path.join(base, "rules"), ".md").map((name) => ({
    id: "ai-risk:" + name, path: "docs/rules/" + name, src: path.join(base, "rules", name), reason: "risk tiers, merge policy and agent-stop rules" }));
  specs.push({ id: "ai-risk:policy", path: "docs/rules/ai-merge-policy.md", src: path.join(base, "assets", "ai-merge-policy.md"),
    reason: "declares the merge policy: conservative, auto-merge off" });
  for (const name of ["classify-tier.sh", "merge-policy.sh"]) {
    specs.push({ id: "ai-risk:" + name, path: "scripts/ai-risk/" + name, src: path.join(base, "scripts", name), reason: "risk tier and policy lookup" });
  }
  return copySteps(ctx, specs);
}

export function templatePath(forge) {
  return { gitlab: ".gitlab/merge_request_templates/default.md", github: ".github/pull_request_template.md" }[forge] ?? null;
}

function prTemplateSteps(ctx) {
  if (!ctx.on("pr-template")) return [];
  const base = source(ctx, "skills/verify-change");
  if (!base || !isDir(base)) return missingClone("pr-template");
  const file = templatePath(ctx.detected.git.forge);
  const specs = [{ id: "pr-template:check", path: "scripts/clean-code/check-pr-body.sh",
    src: path.join(base, "scripts", "check-pr-body.sh"), reason: "validates a PR body against the template" }];
  if (!file) {
    return [new Step("pr-template", "manual", "", "no GitLab or GitHub remote: place assets/pr-body.md as the forge's PR template by hand"),
      ...copySteps(ctx, specs)];
  }
  specs.unshift({ id: "pr-template", path: file, src: path.join(base, "assets", "pr-body.md"),
    reason: "PR/MR description template with the review guide, risk and proof sections" });
  return copySteps(ctx, specs);
}

export function addonFileSteps(ctx) {
  return [...privacySteps(ctx), ...approvalGateSteps(ctx), ...researchRefSteps(ctx), ...aiRiskSteps(ctx), ...prTemplateSteps(ctx)];
}
