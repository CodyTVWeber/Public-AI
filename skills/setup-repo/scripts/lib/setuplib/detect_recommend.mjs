import { SOURCE_HINT, sourceDir } from "./skills_sets.mjs";

const DEBT_HIGH_FILES = 10;
const APPROVAL_WORDS = ["never auto-commit", "explicit approval", "approval before"];
const HOOKS_VIA = [["husky", "husky"], ["lefthook", "lefthook"], ["pre-commit", "precommit"], ["githooks", "githooks"]];
const PROFILES = ["minimal", "standard", "factory"];

function hooksVia(parts) {
  const systems = Object.fromEntries(parts.hook_systems.map((item) => [item.name, item.detail]));
  for (const [name, adapter] of HOOKS_VIA) {
    if (name in systems) return [adapter, name + " present: the checks are added to it"];
  }
  if ("native-own" in systems) return ["githooks", "git hooks from an earlier setup run are chained in .git/hooks: kept current"];
  if ("native-wired" in systems && !("native" in systems)) {
    return ["none", "git hooks already call the clean-code scripts (" + systems["native-wired"] + ")"];
  }
  if ("core.hooksPath" in systems) {
    return ["none", "core.hooksPath is " + systems["core.hooksPath"] + ": never overridden; a manual step lists the calls"];
  }
  if ("simple-git-hooks" in systems) return ["none", "simple-git-hooks present: a manual step lists the calls"];
  return ["githooks", "no hook system found: .githooks with core.hooksPath"];
}

function ciFlag(parts) {
  const { forge } = parts.git;
  const ci = parts.ci;
  const hosted = ["gitlab", "github"];
  if (hosted.includes(forge) && hosted.includes(ci.provider)) {
    return ["--with ci", "existing " + ci.provider + " CI: the adapter adds one separate job file, never edits existing ones"];
  }
  if (["jenkins", "circleci", "azure"].includes(ci.provider)) {
    return ["--without ci", ci.provider + " has no adapter: the plan lists the commands as a manual step"];
  }
  if (!hosted.includes(forge)) return ["--without ci", "no GitLab or GitHub remote: local and Claude hooks are the guardrails"];
  return ["--without ci", "no pipeline in this repo: local and Claude hooks are the guardrails (opt in with --with ci)"];
}

function approvalFlag(parts) {
  if (parts.visibility === "public") {
    return ["--with approval-gate,privacy", "public repo: history is permanent, so commit and push need approval and a privacy scan"];
  }
  const docs = Array.isArray(parts.doc_text) ? parts.doc_text.join(" ").toLowerCase() : "";
  if (APPROVAL_WORDS.some((word) => docs.includes(word))) {
    return ["--with approval-gate", "existing guidance already requires approval before commit or push"];
  }
  return null;
}

function skillsFlag(clone) {
  if (clone) {
    return { flag: "--skills core", reason: "PUBLIC_AI_DIR names a clone: 6 core and 15 support skills are symlinked; --skills core+aliases adds the one-line aliases" };
  }
  return { flag: "--skills none", reason: "no skills source: " + SOURCE_HINT + " to link the core and support skills" };
}

function debtNote(debt) {
  const high = debt.files_over_400_lines >= DEBT_HIGH_FILES || debt.files_with_comment_density_high >= DEBT_HIGH_FILES;
  if (!high) return null;
  return "analyzer stays changed-lines-only: " + debt.files_over_400_lines + " files over 400 lines and "
    + debt.files_with_comment_density_high + " comment-heavy files are never audited; set linter rules to warn first";
}

function buildQuestions(parts, ciChoice) {
  const questions = [];
  const { ci, visibility } = parts;
  const hosted = ["gitlab", "github"];
  if (hosted.includes(ci.provider) || visibility === "public") {
    questions.push({ id: "profile", ask: "Which profile: minimal, standard or factory?", options: PROFILES, default: "standard",
      why: "factory adds a CI job file, ai-risk and the PR template for unattended pipelines" });
  }
  if (ciChoice[0] === "--with ci" && hosted.includes(ci.provider)) {
    questions.push({ id: "ci", ask: "Add the CI guardrails job file?", options: ["yes", "no"], default: "yes",
      why: "CI is the control a PR cannot silently delete; skip it when the repo stays outside pipelines" });
  }
  if (["public", "unknown"].includes(visibility) && hosted.includes(parts.git.forge)) {
    questions.push({ id: "approval-gate", ask: "Gate every git commit and push on human approval?", options: ["yes", "no"],
      default: visibility === "public" ? "yes" : "no",
      why: "right for human-gated repos, wrong for unattended factories; visibility is " + visibility });
  }
  return questions;
}

export function recommend(parts) {
  const [via, viaReason] = hooksVia(parts);
  const flags = [{ flag: "--hooks-via " + via, reason: viaReason }];
  const ciChoice = ciFlag(parts);
  flags.push({ flag: ciChoice[0], reason: ciChoice[1] });
  const approval = approvalFlag(parts);
  if (approval) flags.push({ flag: approval[0], reason: approval[1] });
  flags.push(skillsFlag(sourceDir(null)));
  const notes = [debtNote(parts.legacy_debt)].filter(Boolean);
  if (parts.monorepo.is_monorepo) notes.push("monorepo: install once at the root; wire linter snippets per package dir");
  return { profile: "standard", profile_reason: "hooks on git commands plus Claude Code hooks, no pipeline changes",
    hooks_via: via, flags, questions: buildQuestions(parts, ciChoice), notes };
}
