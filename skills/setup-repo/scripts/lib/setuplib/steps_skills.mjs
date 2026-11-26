import { Step } from "./plan_model.mjs";
import { applyLinks, excludeNeeded, planLinks } from "./skills_link.mjs";
import { SOURCE_HINT, skillNames, sourceDir } from "./skills_sets.mjs";

const LINK_PATH = ".claude/skills/";

function conflictSteps(links) {
  return links.filter((link) => link.status === "conflict").map((link) => new Step("skills:" + link.name, "manual",
    LINK_PATH + link.name, "exists and is not the expected link: leave it, or rerun with --force to replace a link"));
}

export function skillsSteps(ctx) {
  if (!ctx.on("skills")) return [];
  const source = sourceDir(ctx.options.skillsFrom);
  if (source === null) {
    return [new Step("skills", "manual", LINK_PATH, "no Public-AI clone: " + SOURCE_HINT + ", then rerun bootstrap or link-skills.sh")];
  }
  const names = skillNames(ctx.skillDir, source, ctx.options.skills);
  const [links, warnings] = planLinks([ctx.root, source], names, ctx.options.force);
  const changes = links.filter((link) => ["create", "replace"].includes(link.status));
  const steps = conflictSteps(links);
  const extra = warnings.length ? { warnings } : {};
  if (changes.length || excludeNeeded(ctx.root, links)) {
    const reason = "symlinks " + changes.length + " skills from the Public-AI clone, one .git/info/exclude entry per link";
    steps.unshift(new Step("skills", "create", LINK_PATH, reason, { run: () => applyLinks(ctx.root, links), extra }));
  } else steps.unshift(new Step("skills", "skip", LINK_PATH, "skill links already in place", { extra }));
  return steps;
}
