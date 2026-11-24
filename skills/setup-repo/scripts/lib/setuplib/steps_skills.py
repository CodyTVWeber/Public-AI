from .plan_model import Step
from .skills_link import apply_links, exclude_needed, find_source, manifest_names, plan_links


def skills_steps(ctx):
    if not ctx.on("skills"):
        return []
    source = find_source(ctx.options.skills_from)
    if source is None:
        return [Step("skills", "manual", ".claude/skills/", "no Public-AI clone found: set PUBLIC_AI_DIR or pass --skills-from, then run link-skills.sh")]
    names = manifest_names(ctx.skill_dir, source, ctx.options.skills)
    links, warnings = plan_links((ctx.root, source), names, ctx.options.force)
    changes = [link for link in links if link["status"] in ("create", "replace")]
    steps = [Step("skills:" + link["name"], "manual", ".claude/skills/" + link["name"],
                  "exists and is not the expected link: leave it, or rerun with --force to replace a link")
             for link in links if link["status"] == "conflict"]
    extra = {"warnings": warnings} if warnings else {}
    if changes or exclude_needed(ctx.root):
        reason = "symlinks " + str(len(changes)) + " skills from the Public-AI clone and adds .claude/skills/ to .git/info/exclude"
        steps.insert(0, Step("skills", "create", ".claude/skills/", reason, run=lambda: apply_links(ctx.root, links), extra=extra))
    else:
        steps.insert(0, Step("skills", "skip", ".claude/skills/", "skill links already in place", extra=extra))
    return steps
