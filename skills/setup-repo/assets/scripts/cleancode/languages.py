import os
import re
from dataclasses import dataclass

TRIPLE_LENGTH = 3
BLOCK_COMMENT = ("/*", "*/")
DOUBLE_TRIPLE = '"""'
SINGLE_TRIPLE = "'''"


@dataclass(frozen=True)
class LangSpec:
    name: str
    family: str
    line_comments: tuple = ()
    block: tuple = ()
    quotes: tuple = ()
    triples: tuple = ()
    multiline: tuple = ()
    raw: tuple = ()
    heredoc: bool = False
    rust_chars: bool = False
    word_start_comment: bool = False
    url_guard: bool = False
    line_block: tuple = ()


def brace(name, quotes=("'", '"'), **options):
    return LangSpec(name, "brace", ("//",), BLOCK_COMMENT, quotes, **options)


JS = brace("js", ("'", '"', "`"), multiline=("`",), url_guard=True)
JAVA = brace("java", triples=(DOUBLE_TRIPLE,))
KOTLIN = brace("kotlin", triples=(DOUBLE_TRIPLE,))
GO = brace("go", ("'", '"', "`"), multiline=("`",), raw=("`",))
RUST = brace("rust", ('"',), rust_chars=True)
C = brace("c")
CPP = brace("cpp")
CSHARP = brace("cs")
SWIFT = brace("swift", ('"',), triples=(DOUBLE_TRIPLE,))
PHP = brace("php")
SCALA = brace("scala", triples=(DOUBLE_TRIPLE,))
PYTHON = LangSpec(
    "python", "python", ("#",), (), ("'", '"'), (DOUBLE_TRIPLE, SINGLE_TRIPLE)
)
SHELL = LangSpec(
    "shell", "shell", ("#",), (), ("'", '"'), (), ("'", '"'), ("'",),
    heredoc=True, word_start_comment=True,
)
RUBY = LangSpec(
    "ruby", "ruby", ("#",), (), ("'", '"'), (), ("'", '"'),
    heredoc=True, line_block=("=begin", "=end"),
)

BY_EXTENSION = {
    ".js": JS, ".jsx": JS, ".mjs": JS, ".cjs": JS, ".ts": JS, ".tsx": JS,
    ".java": JAVA, ".kt": KOTLIN, ".kts": KOTLIN, ".go": GO, ".rs": RUST,
    ".c": C, ".h": C, ".cc": CPP, ".cpp": CPP, ".hpp": CPP, ".cs": CSHARP,
    ".swift": SWIFT, ".php": PHP, ".scala": SCALA, ".py": PYTHON,
    ".sh": SHELL, ".bash": SHELL, ".rb": RUBY,
}

TEST_DIRECTORIES = frozenset(
    {"test", "tests", "__tests__", "spec", "specs", "__mocks__", "fixtures",
     "testdata", "e2e", "testing"}
)
TEST_NAME = re.compile(r"(\.test\.|\.spec\.|_test\.|_spec\.|^test_|Test\.|Tests\.)")
GENERATED_DIRECTORIES = frozenset(
    {"generated", "__generated__", "node_modules", "vendor", "dist", ".venv",
     "__pycache__", "site-packages"}
)
GENERATED_NAME = re.compile(
    r"(\.d\.ts$|\.generated\.|\.min\.js$|\.pb\.go$|_pb2\.py$|\.designer\.cs$)"
)
LAYER_DIRECTORIES = frozenset(
    {"controller", "controllers", "service", "services", "model", "models"}
)


def spec_for(path):
    return BY_EXTENSION.get(os.path.splitext(path)[1].lower())


def path_parts(path):
    return path.replace("\\", "/").split("/")


def is_test_path(path):
    parts = path_parts(path)
    if any(part in TEST_DIRECTORIES for part in parts[:-1]):
        return True
    return bool(TEST_NAME.search(parts[-1]))


def is_generated_path(path):
    parts = path_parts(path)
    if any(part in GENERATED_DIRECTORIES for part in parts[:-1]):
        return True
    return bool(GENERATED_NAME.search(parts[-1]))


def layer_directory(path):
    for part in path_parts(path)[:-1]:
        if part.lower() in LAYER_DIRECTORIES:
            return part
    return None
