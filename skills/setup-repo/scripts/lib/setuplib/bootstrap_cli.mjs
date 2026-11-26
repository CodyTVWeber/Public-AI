import fs from "node:fs";
import path from "node:path";
import { HelpRequested, parse, UsageError, USAGE } from "./bs_options.mjs";
import { buildProfile } from "./detect_cli.mjs";
import { CHANGED_UPSTREAM, computeDrift, MODIFIED_LOCALLY } from "./drift.mjs";
import { NO_PIPELINE } from "./doc_render.mjs";
import { Context } from "./plan_model.mjs";
import { loadRecord } from "./record.mjs";
import { Repo } from "./repo.mjs";
import { SKILL_DIR, findPublicRoot, sourceRoot } from "./sources.mjs";
import { CONTROL_NOTE, ciSteps } from "./steps_ci.mjs";
import { coreSteps } from "./steps_core.mjs";
import { docSteps, manifestStep } from "./steps_doc.mjs";
import { addonFileSteps, claudeHookSteps } from "./steps_files.mjs";
import { hookSteps, resolveHooksVia } from "./steps_hooks.mjs";
import { excludeStep } from "./steps_local.mjs";
import { skillsSteps } from "./steps_skills.mjs";
import { print, printErr, runMain } from "./util.mjs";

const PRECONDITION_ERROR = 3;
const ACTION_COLUMN = 6;
const LOCAL_NOTE = "local profile: tracked files stay unchanged; installed paths are excluded in .git/info/exclude and the install record is in .git/info";
const ACTIONS = ["create", "merge", "skip", "manual"];

function buildContext(options) {
  const repo = new Repo(options.target);
  const detected = buildProfile(repo, false);
  const [hooksVia, hooksNote] = resolveHooksVia(options, detected);
  const ctx = new Context({ options, repo, detected, features: options.features, hooksVia, hooksNote,
    skillDir: SKILL_DIR, publicRoot: findPublicRoot() });
  ctx.drift = computeDrift(ctx.root, loadRecord(ctx.root), sourceRoot());
  ctx.driftMap = new Map(ctx.drift.map((item) => [item.path, item.status]));
  if (options.upgrade) ctx.upgradePaths = new Set(ctx.drift.filter((item) => item.status === CHANGED_UPSTREAM).map((item) => item.path));
  return ctx;
}

function buildSteps(ctx) {
  const steps = [...coreSteps(ctx), ...addonFileSteps(ctx), ...hookSteps(ctx), ...claudeHookSteps(ctx)];
  steps.push(...ciSteps(ctx), ...skillsSteps(ctx), ...docSteps(ctx));
  return [...steps, ...excludeStep(ctx), manifestStep(ctx)];
}

function runSteps(steps) {
  for (const step of steps) {
    if (!["create", "merge"].includes(step.action) || step.run === null) continue;
    try {
      step.run();
      step.result = "done";
    } catch (error) {
      step.result = "failed: " + String(error.message).slice(0, 200);
    }
  }
}

function summarize(steps) {
  const counts = Object.fromEntries(ACTIONS.map((name) => [name, steps.filter((step) => step.action === name).length]));
  counts.failed = steps.filter((step) => (step.result ?? "").startsWith("failed")).length;
  return counts;
}

function planNotes(ctx) {
  const notes = [...ctx.detected.recommend.notes];
  notes.push(ctx.on("ci") ? CONTROL_NOTE : NO_PIPELINE);
  const kept = ctx.drift.filter((item) => item.status === MODIFIED_LOCALLY).map((item) => item.path);
  if (kept.length) notes.push("modified locally, never overwritten without --force: " + kept.join(", "));
  if (ctx.local) notes.push(LOCAL_NOTE);
  if (ctx.on("approval-gate")) {
    notes.push("approval-gate is for human-gated repos: every commit and push waits for approval; unattended factories leave it off");
  }
  return notes;
}

function printDigest(steps, summary, mode) {
  printErr("bootstrap " + mode + ": " + ACTIONS.map((name) => summary[name] + " " + name).join(", "));
  for (const step of steps) {
    if (["manual", "create", "merge"].includes(step.action)) {
      printErr("  " + step.action.padEnd(ACTION_COLUMN) + " " + step.id + " " + step.path);
    }
    if (step.action === "manual") printErr("         " + step.reason);
  }
}

function checkTarget(options) {
  if (!fs.existsSync(options.target) || !fs.statSync(options.target).isDirectory()) {
    printErr("bootstrap: not a directory: " + options.target);
    return PRECONDITION_ERROR;
  }
  if (!fs.existsSync(path.join(options.target, ".git"))) {
    printErr("bootstrap: not a git repo: " + options.target);
    return PRECONDITION_ERROR;
  }
  return 0;
}

function parseOrExit(argv) {
  try {
    return [parse(argv), 0];
  } catch (error) {
    if (error instanceof HelpRequested) {
      print(USAGE);
      return [null, -1];
    }
    if (!(error instanceof UsageError)) throw error;
    printErr("bootstrap: " + error.message);
    return [null, 2];
  }
}

export function main(argv) {
  const [options, code] = parseOrExit(argv);
  if (options === null) return code === -1 ? 0 : code;
  const failure = checkTarget(options);
  if (failure) return failure;
  const ctx = buildContext(options);
  const steps = buildSteps(ctx);
  const changes = steps.filter((step) => ["create", "merge"].includes(step.action));
  if (options.apply && changes.length && ctx.detected.git.dirty && !options.yes) {
    printErr("bootstrap: working tree has uncommitted changes; rerun with --yes to apply anyway");
    return PRECONDITION_ERROR;
  }
  if (options.apply) runSteps(steps);
  const summary = summarize(steps);
  print(JSON.stringify({ target: ctx.root, mode: options.mode, applied: options.apply, profile: options.profile,
    features: ctx.features, hooks_via: ctx.hooksVia, drift: ctx.drift, steps: steps.map((step) => step.public()),
    summary, notes: planNotes(ctx) }, null, 2));
  printDigest(steps, summary, options.mode);
  return summary.failed ? 1 : 0;
}

runMain(import.meta.url, main);
