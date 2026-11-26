import os

from .drift import differs_reason
from .stale import take_stale
from .installer import note_installed, overwrite_flags, run_install
from .plan_model import Step


def copy_flags(ctx, specs):
    flags = ["--force"] if ctx.options.force else []
    for spec in specs:
        flags += ["--copy", spec["src"], spec["path"]]
    return flags + overwrite_flags(ctx)


def missing_source(spec):
    return Step(spec["id"], "manual", spec["path"], "source file missing: " + os.path.basename(spec["src"]))


def one_step(ctx, spec, item):
    path = spec["path"]
    if item["status"] == "same":
        return Step(spec["id"], "skip", path, "already installed and identical")
    stale = take_stale(ctx, item) if item["status"] == "differs" else None
    if item["status"] == "differs" and not (stale and ctx.options.upgrade):
        return Step(spec["id"], "manual", path, differs_reason(ctx.drift_map, path, stale))
    if stale:
        return Step(spec["id"], "create", path, "replaces an unchanged copy of an earlier upstream version",
                    run=lambda: run_install(ctx, copy_flags(ctx, [spec])))
    reason = spec.get("reason", "installs the file") if item["status"] == "create" else "overwrites the differing file"
    return Step(spec["id"], "create", path, reason, run=lambda: run_install(ctx, copy_flags(ctx, [spec])))


def copy_steps(ctx, specs):
    ready = [spec for spec in specs if os.path.isfile(spec["src"])]
    steps = [missing_source(spec) for spec in specs if spec not in ready]
    if not ready:
        return steps
    report = run_install(ctx, copy_flags(ctx, ready) + ["--dry-run"])
    note_installed(ctx, report)
    by_path = {item["path"]: item for item in report["files"]}
    return [one_step(ctx, spec, by_path[spec["path"]]) for spec in ready] + steps
