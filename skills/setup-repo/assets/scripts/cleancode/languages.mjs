import path from "node:path";

export const TRIPLE_LENGTH = 3;
const BLOCK_COMMENT = ["/*", "*/"];
const DOUBLE_TRIPLE = '"""';
const SINGLE_TRIPLE = "'''";

function spec(name, family, options) {
  return {
    name, family, lineComments: [], block: [], quotes: [], triples: [], multiline: [], raw: [],
    heredoc: false, rustChars: false, wordStartComment: false, urlGuard: false, lineBlock: [], ...options,
  };
}

function brace(name, options = {}) {
  return spec(name, "brace", { lineComments: ["//"], block: BLOCK_COMMENT, quotes: ["'", '"'], ...options });
}

const BACKTICKS = { quotes: ["'", '"', "`"], multiline: ["`"] };
const JS = brace("js", { ...BACKTICKS, urlGuard: true });
const JAVA = brace("java", { triples: [DOUBLE_TRIPLE] });
const KOTLIN = brace("kotlin", { triples: [DOUBLE_TRIPLE] });
const GO = brace("go", { ...BACKTICKS, raw: ["`"] });
const RUST = brace("rust", { quotes: ['"'], rustChars: true });
const C = brace("c");
const CPP = brace("cpp");
const CSHARP = brace("cs");
const SWIFT = brace("swift", { quotes: ['"'], triples: [DOUBLE_TRIPLE] });
const PHP = brace("php");
const SCALA = brace("scala", { triples: [DOUBLE_TRIPLE] });
const PYTHON = spec("python", "python", {
  lineComments: ["#"], quotes: ["'", '"'], triples: [DOUBLE_TRIPLE, SINGLE_TRIPLE],
});
const SHELL = spec("shell", "shell", {
  lineComments: ["#"], quotes: ["'", '"'], multiline: ["'", '"'], raw: ["'"], heredoc: true, wordStartComment: true,
});
const RUBY = spec("ruby", "ruby", {
  lineComments: ["#"], quotes: ["'", '"'], multiline: ["'", '"'], heredoc: true, lineBlock: ["=begin", "=end"],
});

const BY_EXTENSION = new Map(Object.entries({
  ".js": JS, ".jsx": JS, ".mjs": JS, ".cjs": JS, ".ts": JS, ".tsx": JS,
  ".java": JAVA, ".kt": KOTLIN, ".kts": KOTLIN, ".go": GO, ".rs": RUST,
  ".c": C, ".h": C, ".cc": CPP, ".cpp": CPP, ".hpp": CPP, ".cs": CSHARP,
  ".swift": SWIFT, ".php": PHP, ".scala": SCALA, ".py": PYTHON,
  ".sh": SHELL, ".bash": SHELL, ".rb": RUBY,
}));

const TEST_DIRECTORIES = new Set(["test", "tests", "__tests__", "spec", "specs", "__mocks__", "fixtures", "testdata", "e2e", "testing"]);
const TEST_NAME = /(\.test\.|\.spec\.|_test\.|_spec\.|^test_|Test\.|Tests\.)/;
const GENERATED_DIRECTORIES = new Set(["generated", "__generated__", "node_modules", "vendor", "dist", ".venv", "__pycache__", "site-packages"]);
const GENERATED_NAME = /(\.d\.ts$|\.generated\.|\.min\.js$|\.pb\.go$|_pb2\.py$|\.designer\.cs$)/;
const LAYER_DIRECTORIES = new Set(["controller", "controllers", "service", "services", "model", "models"]);

export function specFor(file) {
  return BY_EXTENSION.get(path.extname(file).toLowerCase()) || null;
}

function pathParts(file) {
  return file.replaceAll("\\", "/").split("/");
}

export function isTestPath(file) {
  const parts = pathParts(file);
  if (parts.slice(0, -1).some((part) => TEST_DIRECTORIES.has(part))) return true;
  return TEST_NAME.test(parts[parts.length - 1]);
}

export function isGeneratedPath(file) {
  const parts = pathParts(file);
  if (parts.slice(0, -1).some((part) => GENERATED_DIRECTORIES.has(part))) return true;
  return GENERATED_NAME.test(parts[parts.length - 1]);
}

export function layerDirectory(file) {
  return pathParts(file).slice(0, -1).find((part) => LAYER_DIRECTORIES.has(part.toLowerCase())) ?? null;
}
