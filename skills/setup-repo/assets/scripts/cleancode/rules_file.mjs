import { makeFinding } from "./catalog.mjs";
import { layerDirectory } from "./languages.mjs";
import { ERROR, WARN, startsWithAny } from "./model.mjs";

const MIN_STRING_LENGTH = 6;
const MIN_REPEATS = 3;
const DUPLICATE = ["duplicate-string", WARN];
const IMPORT_MARKERS = ["import ", "from ", "require(", "#include", "use ", "source ", ". "];
const LETTER = /\p{L}/u;

function pyRepr(text) {
  const quote = text.includes("'") && !text.includes('"') ? '"' : "'";
  let out = "";
  for (const char of text) {
    if (char === "\\" || char === quote) out += "\\" + char;
    else if (char === "\n") out += "\\n";
    else if (char === "\r") out += "\\r";
    else if (char === "\t") out += "\\t";
    else if (char < " " || char === "\x7f") out += "\\x" + char.charCodeAt(0).toString(16).padStart(2, "0");
    else out += char;
  }
  return quote + out + quote;
}

export function sizeFindings(ctx) {
  const { src, limits } = ctx;
  if (src.isTest || !ctx.change.grows) return [];
  const total = src.lineCount;
  let severity = null;
  if (total >= limits.fileError) severity = ERROR;
  else if (total > limits.fileWarn) severity = WARN;
  if (severity === null) return [];
  return [makeFinding([src.path, 1], ["file-size", severity], `${total} lines and this change grows it`)];
}

export function layerFindings(ctx) {
  const folder = layerDirectory(ctx.src.path);
  if (folder === null || !ctx.change.isNew || ctx.src.isTest) return [];
  return [makeFinding([ctx.src.path, 1], ["layer-folder", WARN], `new file under layer folder '${folder}'`)];
}

function countable(src, entry) {
  const [number, text] = entry;
  if (text.length < MIN_STRING_LENGTH || !LETTER.test(text)) return false;
  if (src.lang === "shell" && text.includes("$")) return false;
  return !startsWithAny(src.raw[number].trimStart(), IMPORT_MARKERS);
}

export function duplicateFindings(ctx) {
  const { src } = ctx;
  if (src.isTest) return [];
  const seen = new Map();
  for (const entry of src.lexed.strings) {
    if (countable(src, entry)) seen.set(entry[1], [...(seen.get(entry[1]) || []), entry[0]]);
  }
  const findings = [];
  for (const [text, lines] of seen) {
    const touched = lines.filter((line) => ctx.change.has(line));
    if (lines.length >= MIN_REPEATS && touched.length) {
      const message = `string ${pyRepr(text.slice(0, 40))} repeats ${lines.length} times`;
      findings.push(makeFinding([src.path, touched[0]], DUPLICATE, message));
    }
  }
  return findings;
}
