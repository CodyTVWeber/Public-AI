import { differsReason } from "./drift.mjs";
import { noteInstalled, overwriteFlags, runInstall } from "./installer.mjs";
import { Step } from "./plan_model.mjs";
import { takeStale } from "./stale.mjs";

const GROUP_PREFIXES = [["rules", ".claude/rules/"], ["scripts", "scripts/clean-code/"], ["git-hooks", ".githooks/"]];

function githooksActive(ctx) {
  return ctx.on("git-hooks") && ctx.hooksVia === "githooks";
}

function installFlags(ctx) {
  const flags = ["--no-claude-hook", "--no-doc"];
  if (!ctx.on("rules")) flags.push("--no-rules");
  if (!githooksActive(ctx)) flags.push("--no-githooks");
  if (ctx.options.force) flags.push("--force");
  return flags;
}

function callInstall(ctx, extra) {
  return runInstall(ctx, [...installFlags(ctx), ...overwriteFlags(ctx), ...extra]);
}

function corePreview(ctx) {
  if (!("preview" in ctx.cache)) {
    ctx.cache.preview = callInstall(ctx, ["--dry-run"]);
    noteInstalled(ctx, ctx.cache.preview);
  }
  return ctx.cache.preview;
}

function runCore(ctx) {
  if (!("applied" in ctx.cache)) ctx.cache.applied = callInstall(ctx, []);
}

function groupFiles(preview, prefix) {
  return preview.files.filter((item) => item.path.startsWith(prefix));
}

function groupSteps(ctx, spec, files) {
  const [stepId, reason] = spec;
  if (!files.length) return [];
  const stale = new Map(files.filter((item) => item.status === "differs").map((item) => [item.path, takeStale(ctx, item)]));
  const replaced = files.filter((item) => stale.get(item.path) && ctx.options.upgrade);
  const differing = files.filter((item) => stale.has(item.path) && !replaced.includes(item));
  const written = [...files.filter((item) => ["create", "overwrite"].includes(item.status)), ...replaced];
  const steps = differing.map((item) => new Step(stepId + ":" + item.path, "manual", item.path,
    differsReason(ctx.driftMap, item.path, stale.get(item.path))));
  const dir = files[0].path.slice(0, files[0].path.lastIndexOf("/")) + "/";
  if (written.length) {
    steps.unshift(new Step(stepId, "create", dir, reason + " (" + written.length + " files)", { run: () => runCore(ctx) }));
  } else if (!differing.length) {
    steps.unshift(new Step(stepId, "skip", dir, "all " + files.length + " files already installed and identical"));
  }
  return steps;
}

export function coreSteps(ctx) {
  const preview = corePreview(ctx);
  const steps = [];
  if (ctx.on("rules")) {
    steps.push(...groupSteps(ctx, ["rules", "clean-code, ban-comments, small-MR, docs, research and context-reuse rules"],
      groupFiles(preview, GROUP_PREFIXES[0][1])));
  }
  steps.push(...groupSteps(ctx, ["scripts", "analyzer, size gate, git guards and git-command scanner"],
    groupFiles(preview, GROUP_PREFIXES[1][1])));
  return steps;
}

export function githooksSteps(ctx) {
  const preview = corePreview(ctx);
  const files = groupFiles(preview, GROUP_PREFIXES[2][1]);
  const steps = groupSteps(ctx, ["git-hooks", "git pre-commit and pre-push via core.hooksPath=.githooks"], files);
  const { status, note } = preview.git_hooks;
  if (status === "foreign") steps.push(new Step("git-hooks:hooks-path", "manual", "core.hooksPath", note));
  else if (status === "set" && steps.length && steps[0].action === "skip") {
    steps[0] = new Step("git-hooks", "merge", "core.hooksPath", "sets core.hooksPath=.githooks", { run: () => runCore(ctx) });
  }
  return steps;
}
