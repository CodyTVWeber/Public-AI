import json
import os
import subprocess
import tempfile

from .hookspec import GROUPS, PROJECT_DIR
from .repo import Repo
from .verify_common import CORE_SCRIPTS, file_has, is_executable, load_manifest, result
from .verify_git import check_git_hooks

CHECK_TIMEOUT_SECONDS = 60
CORE_PACKAGES = ("cleancode/cli.py", "gitscan/cli.py")
HOOK_GROUPS_BY_FEATURE = {"claude-hooks": ("guard", "docs-lint", "analyzer", "stop"), "post-git-hook": ("post-git",),
                          "approval-gate": ("approval-gate",), "research-ref": ("research-ref",)}
SEEDED_VIOLATION = "export const probe = 1;\n// a note\n"
SEEDED_CLEAN = "export const probe = 1;\n"
GIT_IDENTITY = ["-c", "user.name=probe", "-c", "user.email=probe.example", "-c", "commit.gpgsign=false"]


def check_scripts(root):
    missing = [name for name in CORE_SCRIPTS if not is_executable(os.path.join(root, "scripts", "clean-code", name))]
    missing += [name for name in CORE_PACKAGES if not os.path.isfile(os.path.join(root, "scripts", "clean-code", name))]
    if missing:
        return result("scripts", "fail", "missing or not executable in scripts/clean-code: " + ", ".join(missing))
    return result("scripts", "pass", "analyzer, guards and scanner are installed")


def expected_commands(manifest, registered):
    if manifest is None:
        return [command for command in registered if "scripts/clean-code" in command]
    groups = [group for feature in manifest["features"] for group in HOOK_GROUPS_BY_FEATURE.get(feature, ())]
    return [spec.command for group in groups for spec in GROUPS[group]]


def registered_commands(settings):
    hooks = settings.get("hooks") or {}
    return [hook.get("command", "") for entries in hooks.values() for entry in entries for hook in entry.get("hooks", [])]


def check_settings(root, manifest):
    path = os.path.join(root, ".claude", "settings.json")
    if not os.path.isfile(path):
        wanted = manifest and any(feature in HOOK_GROUPS_BY_FEATURE for feature in manifest["features"])
        return result("settings", "fail" if wanted else "skip", "no .claude/settings.json")
    try:
        with open(path) as handle:
            settings = json.load(handle)
    except ValueError as error:
        return result("settings", "fail", "settings.json is not valid JSON: " + str(error))
    registered = registered_commands(settings)
    missing = [command for command in expected_commands(manifest, registered) if command not in registered]
    if missing:
        return result("settings", "fail", "hooks not registered: " + "; ".join(missing))
    return result("settings", "pass", str(len(registered)) + " hook commands registered")


def check_hook_scripts(root):
    path = os.path.join(root, ".claude", "settings.json")
    try:
        with open(path) as handle:
            commands = registered_commands(json.load(handle))
    except (OSError, ValueError):
        return result("hook-scripts", "skip", "no readable settings.json")
    prefix = PROJECT_DIR + "/"
    missing = []
    for command in commands:
        if command.startswith(prefix):
            script = command[len(prefix):].split(" ")[0]
            if not is_executable(os.path.join(root, script)):
                missing.append(script)
    if missing:
        return result("hook-scripts", "fail", "registered scripts missing or not executable: " + ", ".join(sorted(set(missing))))
    return result("hook-scripts", "pass", "every registered script exists and is executable")


def run_analyzer(root, cwd, name):
    command = [os.path.join(root, "scripts", "clean-code", "code-quality-check.sh"), name]
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=CHECK_TIMEOUT_SECONDS).returncode


def check_analyzer(root):
    if not is_executable(os.path.join(root, "scripts", "clean-code", "code-quality-check.sh")):
        return result("analyzer", "fail", "scripts/clean-code/code-quality-check.sh is missing")
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["git", "init", "-q", tmp], capture_output=True, check=False)
        with open(os.path.join(tmp, "base.ts"), "w") as handle:
            handle.write("export const base = 1;\n")
        subprocess.run(["git", "-C", tmp, "add", "--", "base.ts"], capture_output=True, check=False)
        subprocess.run(["git", "-C", tmp] + GIT_IDENTITY + ["commit", "-q", "-m", "base"], capture_output=True, check=False)
        return seeded_analyzer_run(root, tmp)


def seeded_analyzer_run(root, tmp):
    probe = os.path.join(tmp, "probe.ts")
    with open(probe, "w") as handle:
        handle.write(SEEDED_VIOLATION)
    dirty = run_analyzer(root, tmp, "probe.ts")
    with open(probe, "w") as handle:
        handle.write(SEEDED_CLEAN)
    clean = run_analyzer(root, tmp, "probe.ts")
    if dirty == 1 and clean == 0:
        return result("analyzer", "pass", "exits 1 on a seeded comment, 0 once clean")
    return result("analyzer", "fail", "seeded violation exit " + str(dirty) + " (want 1), clean exit " + str(clean) + " (want 0)")


def check_post_git(root):
    hook = os.path.join(root, "scripts", "clean-code", "post-git-check.sh")
    if not is_executable(hook):
        return result("post-git", "skip", "post-git-check.sh not installed")
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "ls"}, "cwd": root})
    run = subprocess.run([hook], input=payload, capture_output=True, text=True, timeout=CHECK_TIMEOUT_SECONDS)
    if run.returncode == 0 and not run.stdout.strip():
        return result("post-git", "pass", "silent on a non-git command")
    return result("post-git", "fail", "expected exit 0 and no output on `ls`, got exit " + str(run.returncode))


def check_skills(root, manifest):
    base = os.path.join(root, ".claude", "skills")
    links = [os.path.join(base, name) for name in sorted(os.listdir(base))] if os.path.isdir(base) else []
    dangling = [os.path.basename(link) for link in links if os.path.islink(link) and not os.path.exists(link)]
    if dangling:
        return result("skills", "fail", "dangling skill links: " + ", ".join(dangling))
    wanted = manifest and "skills" in manifest["features"]
    if wanted and not links:
        return result("skills", "fail", "skills are in the install record but .claude/skills is empty")
    return result("skills", "pass" if links else "skip", str(len(links)) + " skill links resolve")


def check_ci(root, manifest):
    if not manifest or "ci" not in manifest["features"]:
        return result("ci", "skip", "ci not in the install record")
    candidates = (".gitlab/ci/ai-guardrails.yml", ".github/workflows/ai-guardrails.yml")
    found = [name for name in candidates if os.path.isfile(os.path.join(root, name))]
    if found:
        return result("ci", "pass", found[0])
    return result("ci", "fail", "ci is in the install record but no guardrails job file exists")


def check_doc(root, manifest):
    if not manifest or "agents-doc" not in manifest["features"]:
        return result("agents-doc", "skip", "agents-doc not in the install record")
    for name in ("AGENTS.md", "CLAUDE.md"):
        if file_has(os.path.join(root, name), "<!-- ai-guardrails:begin -->"):
            return result("agents-doc", "pass", name + " holds the AI guardrails section")
    return result("agents-doc", "fail", "no AI guardrails section in AGENTS.md or CLAUDE.md")


def run_checks(root):
    repo = Repo(root)
    manifest = load_manifest(root)
    return [check_scripts(root), check_git_hooks(root, repo, manifest), check_settings(root, manifest),
            check_hook_scripts(root), check_analyzer(root), check_post_git(root), check_skills(root, manifest),
            check_ci(root, manifest), check_doc(root, manifest)], manifest
