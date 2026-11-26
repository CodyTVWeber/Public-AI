from .skills_sets import SOURCE_HINT, source_dir

DEBT_HIGH_FILES = 10
APPROVAL_WORDS = ("never auto-commit", "explicit approval", "approval before")
HOOKS_VIA = {"husky": "husky", "lefthook": "lefthook", "pre-commit": "precommit", "githooks": "githooks"}
PROFILES = ("minimal", "standard", "factory")


def hooks_via(parts):
    systems = {item["name"]: item["detail"] for item in parts["hook_systems"]}
    for name, adapter in HOOKS_VIA.items():
        if name in systems:
            return adapter, name + " present: the checks are added to it"
    if "native-own" in systems:
        return "githooks", "git hooks from an earlier setup run are chained in .git/hooks: kept current"
    if "native-wired" in systems and "native" not in systems:
        return "none", "git hooks already call the clean-code scripts (" + systems["native-wired"] + ")"
    if "core.hooksPath" in systems:
        return "none", "core.hooksPath is " + systems["core.hooksPath"] + ": never overridden; a manual step lists the calls"
    if "simple-git-hooks" in systems:
        return "none", "simple-git-hooks present: a manual step lists the calls"
    return "githooks", "no hook system found: .githooks with core.hooksPath"


def ci_flag(parts):
    forge, ci = parts["git"]["forge"], parts["ci"]
    if forge in ("gitlab", "github") and ci["provider"] in ("gitlab", "github"):
        return ("--with ci", "existing " + ci["provider"] + " CI: the adapter adds one separate job file, never edits existing ones")
    if ci["provider"] in ("jenkins", "circleci", "azure"):
        return ("--without ci", ci["provider"] + " has no adapter: the plan lists the commands as a manual step")
    if forge not in ("gitlab", "github"):
        return ("--without ci", "no GitLab or GitHub remote: local and Claude hooks are the guardrails")
    return ("--without ci", "no pipeline in this repo: local and Claude hooks are the guardrails (opt in with --with ci)")


def approval_flag(parts):
    visibility = parts["visibility"]
    if visibility == "public":
        return ("--with approval-gate,privacy", "public repo: history is permanent, so commit and push need approval and a privacy scan")
    docs = " ".join(parts.get("doc_text", "")).lower() if isinstance(parts.get("doc_text"), list) else ""
    if any(word in docs for word in APPROVAL_WORDS):
        return ("--with approval-gate", "existing guidance already requires approval before commit or push")
    return None


def skills_flag(clone):
    if clone:
        return {"flag": "--skills core", "reason": "PUBLIC_AI_DIR names a clone: 6 core and 15 support skills are symlinked; --skills core+aliases adds the one-line aliases"}
    return {"flag": "--skills none", "reason": "no skills source: " + SOURCE_HINT + " to link the core and support skills"}


def debt_note(debt):
    high = debt["files_over_400_lines"] >= DEBT_HIGH_FILES or debt["files_with_comment_density_high"] >= DEBT_HIGH_FILES
    if not high:
        return None
    return ("analyzer stays changed-lines-only: " + str(debt["files_over_400_lines"]) + " files over 400 lines and "
            + str(debt["files_with_comment_density_high"]) + " comment-heavy files are never audited; set linter rules to warn first")


def build_questions(parts, ci_choice):
    questions = []
    ci, visibility = parts["ci"], parts["visibility"]
    if ci["provider"] in ("gitlab", "github") or visibility == "public":
        questions.append({"id": "profile", "ask": "Which profile: minimal, standard or factory?", "options": list(PROFILES),
                          "default": "standard", "why": "factory adds a CI job file, ai-risk and the PR template for unattended pipelines"})
    if ci_choice[0] == "--with ci" and ci["provider"] in ("gitlab", "github"):
        questions.append({"id": "ci", "ask": "Add the CI guardrails job file?", "options": ["yes", "no"], "default": "yes",
                          "why": "CI is the control a PR cannot silently delete; skip it when the repo stays outside pipelines"})
    if visibility in ("public", "unknown") and parts["git"]["forge"] in ("gitlab", "github"):
        questions.append({"id": "approval-gate", "ask": "Gate every git commit and push on human approval?", "options": ["yes", "no"],
                          "default": "yes" if visibility == "public" else "no",
                          "why": "right for human-gated repos, wrong for unattended factories; visibility is " + visibility})
    return questions


def recommend(parts):
    via, via_reason = hooks_via(parts)
    flags = [{"flag": "--hooks-via " + via, "reason": via_reason}]
    ci_choice = ci_flag(parts)
    flags.append({"flag": ci_choice[0], "reason": ci_choice[1]})
    approval = approval_flag(parts)
    if approval:
        flags.append({"flag": approval[0], "reason": approval[1]})
    flags.append(skills_flag(source_dir(None)))
    notes = [note for note in (debt_note(parts["legacy_debt"]),) if note]
    if parts["monorepo"]["is_monorepo"]:
        notes.append("monorepo: install once at the root; wire linter snippets per package dir")
    return {"profile": "standard", "profile_reason": "hooks on git commands plus Claude Code hooks, no pipeline changes",
            "hooks_via": via, "flags": flags, "questions": build_questions(parts, ci_choice), "notes": notes}
