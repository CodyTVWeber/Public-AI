import os
import re

from .plan_model import Step, file_step, write_bytes

GITLAB_FILE = ".gitlab/ci/ai-guardrails.yml"
GITHUB_FILE = ".github/workflows/ai-guardrails.yml"
ROOT_CI = ".gitlab-ci.yml"
INCLUDE_LINE = "  - local: " + GITLAB_FILE
CONTROL_NOTE = ("CI is the control a PR cannot silently delete: local hooks and .claude settings ship in the same diff "
                "and can be edited out, so make these jobs required and protect the CI files with code owners")
MANUAL_COMMANDS = ('scripts/clean-code/pre-push-gate.sh "$BASE"\nscripts/clean-code/code-quality-check.sh --changed "$BASE"\n'
                   'scripts/clean-code/lint-docs.sh "$BASE"\n')


def read_asset(ctx, name):
    with open(os.path.join(ctx.assets, "ci", name)) as handle:
        return handle.read()


def gitlab_stage(text):
    match = re.search(r"^stages:\s*\n((?:[ \t]+-.*\n?)+)", text, re.M)
    if not match:
        return "test"
    names = [line.strip().lstrip("-").strip() for line in match.group(1).splitlines()]
    return "test" if "test" in names else ".pre"


def gitlab_file_text(ctx):
    root = ctx.dest(ROOT_CI)
    stage = gitlab_stage(open(root).read()) if os.path.exists(root) else "test"
    text = read_asset(ctx, "gitlab-ai-guardrails.yml").replace("{{STAGE}}", stage)
    if ctx.on("pr-template"):
        text += read_asset(ctx, "gitlab-pr-body-job.yml")
    return text.encode()


def include_block_end(lines, start):
    end = start
    for index in range(start + 1, len(lines)):
        line = lines[index]
        if line.strip() and not line[0].isspace() and not line.startswith("-"):
            break
        end = index if line.strip() else end
    return end


def add_include(text):
    lines = text.split("\n")
    heads = [i for i, line in enumerate(lines) if re.match(r"^include:\s*(#.*)?$", line)]
    if not text.strip():
        return "include:\n" + INCLUDE_LINE + "\n"
    if any(re.match(r"^include:\s*\S", line) for line in lines) or len(heads) > 1:
        return None
    if not heads:
        return text.rstrip("\n") + "\n\ninclude:\n" + INCLUDE_LINE + "\n"
    end = include_block_end(lines, heads[0])
    first = next((l for l in lines[heads[0] + 1:end + 1] if l.strip().startswith("-")), None)
    if first is None:
        return None
    indent = first[:len(first) - len(first.lstrip())]
    lines.insert(end + 1, indent + "- local: " + GITLAB_FILE)
    return "\n".join(lines)


def gitlab_include_step(ctx):
    root = ctx.dest(ROOT_CI)
    current = open(root).read() if os.path.exists(root) else None
    if current is not None and GITLAB_FILE in current:
        return Step("ci:include", "skip", ROOT_CI, "already includes the guardrails job file")
    updated = add_include(current or "")
    if updated is None:
        return Step("ci:include", "manual", ROOT_CI, "include: is not a simple list: add `- local: " + GITLAB_FILE + "` by hand",
                    extra={"snippet": INCLUDE_LINE + "\n"})
    action = "merge" if current is not None else "create"
    return Step("ci:include", action, ROOT_CI, "includes the guardrails job file",
                run=lambda: write_bytes(root, updated.encode(), False))


def github_file_text(ctx):
    text = read_asset(ctx, "github-ai-guardrails.yml")
    if ctx.on("pr-template"):
        text += read_asset(ctx, "github-pr-body-step.yml")
    return text.encode()


def ci_provider(ctx):
    forge = ctx.detected["git"]["forge"]
    if forge in ("gitlab", "github"):
        return forge
    provider = ctx.detected["ci"]["provider"]
    return provider if provider in ("gitlab", "github") else None


def ci_file_path(ctx):
    provider = ci_provider(ctx)
    return {"gitlab": GITLAB_FILE, "github": GITHUB_FILE}.get(provider)


def ci_steps(ctx):
    if not ctx.on("ci"):
        return []
    provider = ci_provider(ctx)
    if provider is None:
        return [Step("ci", "manual", "", "no GitLab or GitHub adapter for this repo: run these in your pipeline. " + CONTROL_NOTE,
                     extra={"snippet": MANUAL_COMMANDS})]
    if provider == "gitlab":
        spec = {"id": "ci", "path": GITLAB_FILE, "reason": "GitLab job file: mr-size, clean-code, docs-lint. " + CONTROL_NOTE}
        return [file_step(ctx, spec, gitlab_file_text(ctx)), gitlab_include_step(ctx)]
    spec = {"id": "ci", "path": GITHUB_FILE, "reason": "GitHub workflow of its own, existing workflows untouched. " + CONTROL_NOTE}
    return [file_step(ctx, spec, github_file_text(ctx))]
