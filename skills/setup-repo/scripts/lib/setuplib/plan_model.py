import os
import stat
from dataclasses import dataclass, field
from typing import Callable, Optional

EXEC_MODE = 0o755


@dataclass
class Step:
    id: str
    action: str
    path: str
    reason: str
    run: Optional[Callable] = None
    extra: dict = field(default_factory=dict)
    result: Optional[str] = None

    def public(self):
        data = {"id": self.id, "action": self.action, "path": self.path, "reason": self.reason}
        data.update(self.extra)
        if self.result is not None:
            data["result"] = self.result
        return data


@dataclass
class Context:
    options: object
    repo: object
    detected: dict
    features: list
    hooks_via: str
    hooks_note: dict
    skill_dir: str
    public_root: Optional[str]
    cache: dict = field(default_factory=dict)
    installed: dict = field(default_factory=dict)
    upgrade_paths: set = field(default_factory=set)
    drift_map: dict = field(default_factory=dict)
    drift: list = field(default_factory=list)

    @property
    def assets(self):
        return os.path.join(self.skill_dir, "assets")

    @property
    def root(self):
        return self.repo.root

    @property
    def local(self):
        return self.options.profile == "local"

    @property
    def settings_rel(self):
        return ".claude/settings.local.json" if self.local else ".claude/settings.json"

    def on(self, feature):
        return feature in self.features

    def dest(self, rel):
        return os.path.join(self.root, rel)


def read_bytes(path):
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except OSError:
        return None


def make_executable(path):
    os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def write_bytes(path, data, executable):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(data)
    if executable:
        make_executable(path)


def state_of(dest, data):
    current = read_bytes(dest)
    if current is None:
        return "create"
    return "same" if current == data else "differs"


def file_step(ctx, spec, data):
    step_id, rel, executable = spec["id"], spec["path"], spec.get("executable", False)
    dest = ctx.dest(rel)
    state = state_of(dest, data)
    if state == "same":
        return Step(step_id, "skip", rel, "already installed and identical")
    if state == "differs" and not ctx.options.force:
        return Step(step_id, "manual", rel, "exists and differs: diff it and keep the stricter value, or rerun with --force")
    reason = spec.get("reason", "installs the file") if state == "create" else "overwrites the differing file (--force)"
    return Step(step_id, "create", rel, reason, run=lambda: write_bytes(dest, data, executable))


def copy_tree_files(src_dir, pattern_ext):
    if not os.path.isdir(src_dir):
        return []
    return sorted(name for name in os.listdir(src_dir) if name.endswith(pattern_ext))
