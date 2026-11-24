from dataclasses import dataclass, field

ERROR = "error"
WARN = "warn"


@dataclass(frozen=True)
class Finding:
    file: str
    line: int
    rule: str
    severity: str
    message: str
    fix_hint: str

    def to_dict(self):
        return {
            "file": self.file,
            "line": self.line,
            "rule": self.rule,
            "severity": self.severity,
            "message": self.message,
            "fix_hint": self.fix_hint,
        }


@dataclass(frozen=True)
class Param:
    name: str
    type_text: str
    default: str
    raw: str


@dataclass
class Function:
    name: str
    start: int
    header_end: int
    end: int
    params: list = field(default_factory=list)
    max_depth: int = 0
    depth_line: int = 0
    logic: int = 0


@dataclass
class Block:
    kind: str
    start: int
    end: int
    empty: bool
    owner: object = None


@dataclass
class Structure:
    functions: list = field(default_factory=list)
    blocks: list = field(default_factory=list)
