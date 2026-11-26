from .plan_model import Step
from .skills_link import apply_links, exclude_needed, plan_links
from .skills_sets import SOURCE_HINT, skill_names, source_dir

LINK_PATH = ".claude/skills/"


def conflict_steps(links):
    return [Step("skills:" + link["name"], "manual", LINK_PATH + link["name"],
                 "exists and is not the expected link: leave it, or rerun with --force to replace a link")
            for link in links if link["status"] == "conflict"]


def skills_steps(ctx):
    if not ctx.on("skills"):
        return []
    source = source_dir(ctx.options.skills_from)
    if source is None:
        return [Step("skills", "manual", LINK_PATH, "no Public-AI clone: " + SOURCE_HINT + ", then rerun bootstrap or link-skills.sh")]
    names = skill_names(ctx.skill_dir, source, ctx.options.skills)
    links, warnings = plan_links((ctx.root, source), names, ctx.options.force)
    changes = [link for link in links if link["status"] in ("create", "replace")]
    steps = conflict_steps(links)
    extra = {"warnings": warnings} if warnings else {}
    if changes or exclude_needed(ctx.root, links):
        reason = "symlinks " + str(len(changes)) + " skills from the Public-AI clone, one .git/info/exclude entry per link"
        steps.insert(0, Step("skills", "create", LINK_PATH, reason, run=lambda: apply_links(ctx.root, links), extra=extra))
    else:
        steps.insert(0, Step("skills", "skip", LINK_PATH, "skill links already in place", extra=extra))
    return steps
