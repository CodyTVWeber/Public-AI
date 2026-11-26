import fs from "node:fs";
import path from "node:path";
import { callsSnippet, huskyLines, huskyMarker, lefthookSnippet, nativeBody, OWN_MARKER, precommitSnippet, SHEBANG } from "./hook_snippets.mjs";
import { makeExecutable, Step, writeBytes } from "./plan_model.mjs";
import { githooksSteps } from "./steps_core.mjs";
import { exists, isFile, readText } from "./util.mjs";

const GIT_HOOK_NAMES = ["pre-commit", "pre-push"];
const PRIVACY_HOOK = "commit-msg";
const NO_NOTE = { text: "", manual: false };

function localHooksVia(options, systems) {
  if (options.hooksVia === "none") return ["none", NO_NOTE];
  const hooksPath = systems.get("core.hooksPath");
  if (hooksPath) {
    return ["none", { text: "core.hooksPath is " + hooksPath + ": hooks in .git/hooks would not run and the local profile never sets it", manual: true }];
  }
  return ["native", NO_NOTE];
}

function githooksVariant(systems) {
  const hooksPath = systems.get("core.hooksPath") ?? ".githooks";
  if (hooksPath !== ".githooks") return ["none", { text: "core.hooksPath is " + hooksPath + ": never overridden", manual: true }];
  if (systems.has("native") || systems.has("native-own")) {
    const detail = systems.get("native") ?? systems.get("native-own");
    return ["native", { text: "git hooks in .git/hooks (" + detail + ") are chained, foreign ones kept as .bak", manual: false }];
  }
  return ["githooks", NO_NOTE];
}

function recommendedNote(detected, systems) {
  if (detected.recommend.hooks_via !== "none") return NO_NOTE;
  const found = detected.recommend.flags.find((flag) => flag.flag.startsWith("--hooks-via"));
  const manual = (systems.get("core.hooksPath") ?? ".githooks") !== ".githooks" || systems.has("simple-git-hooks");
  return { text: found ? found.reason : "", manual };
}

export function resolveHooksVia(options, detected) {
  const systems = new Map(detected.hook_systems.map((item) => [item.name, item.detail]));
  if (options.profile === "local") return localHooksVia(options, systems);
  let via = options.hooksVia;
  let note = NO_NOTE;
  if (via === "auto") {
    via = detected.recommend.hooks_via;
    note = recommendedNote(detected, systems);
  }
  return via === "githooks" ? githooksVariant(systems) : [via, note];
}

function privacyWanted(ctx) {
  return ctx.on("privacy") || isFile(ctx.dest("scripts/check-privacy.sh"));
}

function hookNames(ctx) {
  return privacyWanted(ctx) ? [...GIT_HOOK_NAMES, PRIVACY_HOOK] : GIT_HOOK_NAMES;
}

function writeHusky(dest, text, lines) {
  const body = lines.join("\n") + "\n";
  if (text === null) writeBytes(dest, Buffer.from(SHEBANG + "\n" + body), true);
  else writeBytes(dest, Buffer.from(text + (text.endsWith("\n") ? "" : "\n") + body), true);
}

function appendStep(ctx, hook) {
  const rel = ".husky/" + hook;
  const lines = huskyLines(hook, privacyWanted(ctx));
  if (!lines.length) return null;
  const dest = ctx.dest(rel);
  const text = exists(dest) ? readText(dest) : null;
  if (text !== null && text.includes(huskyMarker(hook))) {
    return new Step("git-hooks:" + hook, "skip", rel, "husky hook already calls the clean-code scripts");
  }
  return new Step("git-hooks:" + hook, text !== null ? "merge" : "create", rel, "husky hook gets the clean-code call lines",
    { run: () => writeHusky(dest, text, lines) });
}

function huskySteps(ctx) {
  return hookNames(ctx).map((hook) => appendStep(ctx, hook)).filter(Boolean);
}

function hooksDir(ctx) {
  const out = (ctx.repo.git("rev-parse", "--git-path", "hooks") || ".git/hooks").trim();
  return out.startsWith("/") ? out : path.join(ctx.root, out);
}

function displayPath(ctx, file) {
  const rel = path.relative(ctx.root, file);
  return rel.startsWith("..") ? file : rel;
}

function installNative(file, body, backup = false) {
  if (backup) {
    fs.renameSync(file, file + ".bak");
    makeExecutable(file + ".bak");
  }
  writeBytes(file, Buffer.from(body), true);
}

function nativeForeignStep(id, paths, texts) {
  const [file, shown] = paths;
  const [existing, body] = texts;
  if (existing.includes("scripts/clean-code")) return new Step(id, "skip", shown, "existing hook already calls the clean-code scripts");
  if (exists(file + ".bak")) {
    return new Step(id, "manual", shown, "foreign hook exists and " + path.basename(file) + ".bak is taken: move one aside");
  }
  return new Step(id, "merge", shown, "foreign hook kept as " + path.basename(file) + ".bak, still runs after the checks",
    { run: () => installNative(file, body, true) });
}

function nativeStep(ctx, hook) {
  const file = path.join(hooksDir(ctx), hook);
  const body = nativeBody(hook, privacyWanted(ctx));
  const shown = displayPath(ctx, file);
  const existing = exists(file) ? readText(file) : null;
  const id = "git-hooks:" + hook;
  if (existing === body) return new Step(id, "skip", shown, "hook already chains the clean-code checks");
  if (existing !== null && !existing.includes(OWN_MARKER)) return nativeForeignStep(id, [file, shown], [existing, body]);
  return new Step(id, existing ? "merge" : "create", shown, "git hook runs the clean-code checks", { run: () => installNative(file, body) });
}

function snippetStep(name, file, snippet) {
  const reason = name + " owns the hooks: add this by hand (the plan never rewrites its config)";
  return [new Step("git-hooks", "manual", file, reason, { extra: { snippet } })];
}

export function hookSteps(ctx) {
  if (!ctx.on("git-hooks")) return [];
  const privacy = privacyWanted(ctx);
  const via = ctx.hooksVia;
  if (via === "githooks") return githooksSteps(ctx);
  if (via === "husky") return huskySteps(ctx);
  if (via === "native") return hookNames(ctx).map((hook) => nativeStep(ctx, hook));
  if (via === "lefthook") return snippetStep("lefthook", "lefthook.yml", lefthookSnippet(privacy));
  if (via === "precommit") return snippetStep("pre-commit framework", ".pre-commit-config.yaml", precommitSnippet(privacy));
  const note = ctx.hooksNote;
  const reason = note.text || "hooks-via none: the repo's own hook setup runs the checks";
  const extra = note.manual ? { snippet: callsSnippet(privacy) } : {};
  return [new Step("git-hooks", note.manual ? "manual" : "skip", "", reason, { extra })];
}
