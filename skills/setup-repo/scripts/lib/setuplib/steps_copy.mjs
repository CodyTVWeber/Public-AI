import path from "node:path";
import { differsReason } from "./drift.mjs";
import { noteInstalled, overwriteFlags, runInstall } from "./installer.mjs";
import { Step } from "./plan_model.mjs";
import { takeStale } from "./stale.mjs";
import { isFile } from "./util.mjs";

function copyFlags(ctx, specs) {
  const flags = ctx.options.force ? ["--force"] : [];
  for (const spec of specs) flags.push("--copy", spec.src, spec.path);
  return [...flags, ...overwriteFlags(ctx)];
}

function missingSource(spec) {
  return new Step(spec.id, "manual", spec.path, "source file missing: " + path.basename(spec.src));
}

function oneStep(ctx, spec, item) {
  const file = spec.path;
  const install = () => runInstall(ctx, copyFlags(ctx, [spec]));
  if (item.status === "same") return new Step(spec.id, "skip", file, "already installed and identical");
  const stale = item.status === "differs" ? takeStale(ctx, item) : null;
  if (item.status === "differs" && !(stale && ctx.options.upgrade)) {
    return new Step(spec.id, "manual", file, differsReason(ctx.driftMap, file, stale));
  }
  if (stale) {
    return new Step(spec.id, "create", file, "replaces an unchanged copy of an earlier upstream version", { run: install });
  }
  const reason = item.status === "create" ? (spec.reason ?? "installs the file") : "overwrites the differing file";
  return new Step(spec.id, "create", file, reason, { run: install });
}

export function copySteps(ctx, specs) {
  const ready = specs.filter((spec) => isFile(spec.src));
  const steps = specs.filter((spec) => !ready.includes(spec)).map(missingSource);
  if (!ready.length) return steps;
  const report = runInstall(ctx, [...copyFlags(ctx, ready), "--dry-run"]);
  noteInstalled(ctx, report);
  const byPath = new Map(report.files.map((item) => [item.path, item]));
  return [...ready.map((spec) => oneStep(ctx, spec, byPath.get(spec.path))), ...steps];
}
