import { ERROR, WARN } from "./model.mjs";

const BOTH = "error/warn";

const RULES = [
  ["added-comment", ERROR, "Comment added or touched; code ships with no comments (tests included)",
    "Delete the comment: rename, extract a named function, or name the constant (rules/ban-comments.md)."],
  ["docstring", WARN, "Python docstring attached to a module, class or function",
    "Name the code so it needs no docstring; a free-floating string used as a comment is an error."],
  ["todo-marker", ERROR, "TODO, FIXME or XXX in an added comment",
    "Move it to the tracker; code ships with no TODO markers."],
  ["banner", ERROR, "Section banner or STATUS: line",
    "Order the file (public API first, helpers below); docs describe the present."],
  ["empty-catch", ERROR, "Empty catch/except handler",
    "Call a named helper such as ignoreOptionalFailure(err) instead of an empty handler."],
  ["param-count", BOTH, "Function with 4+ params (error) or 3 params (warn)",
    "Group related params into an options object or split the function."],
  ["function-length", BOTH, "Function over the CC_FUNC_SIZE error cap (default b: 40) or warn cap (default b: 20)",
    "Extract named functions until the body is at or under the warn cap (default b: 20 logic lines)."],
  ["nesting-depth", BOTH, "Control-flow nesting of 4+ (error) or 3 (warn)",
    "Use early returns and guard clauses or extract a named function."],
  ["file-size", BOTH, "File over 400 lines (error) or 200 (warn) that the change grows",
    "Extract a module before growing the file; one responsibility per file."],
  ["param-mutation", BOTH, "Assignment to a parameter's property or index, or compound assignment to a parameter (warn for res, req, ctx, event and ref.current idioms)",
    "Compute and return a new value; the caller assigns. If mutation is the point, name the function so."],
  ["bool-flag-param", WARN, "Boolean flag parameter named is*, has*, should* or enable*",
    "Replace the boolean with an enum that names each outcome, or split into two functions."],
  ["magic-number", WARN, "Numeric literal other than -1, 0, 1, 2 outside a named constant",
    "Extract a named constant that states the meaning."],
  ["layer-folder", WARN, "New file under a controller, service or model folder",
    "Group by feature or domain instead of by technical layer."],
  ["duplicate-string", WARN, "Same string literal (6+ chars) three or more times in a file",
    "Extract a named constant and reuse it."],
  ["inline-try-catch", WARN, "Non-trivial try/catch inline in a function longer than 10 lines",
    "Move the try/catch into a named function that states the attempt, such as readCachedProfile()."],
  ["function-order", WARN, "Caller below its callee, or a private helper above a public function in the same block",
    "Put the caller above the callee, and the public API above helpers."],
  ["guard-clause", WARN, "One if, with no else, holds the whole body of a function of 8 or more logic lines",
    "Return early on the failing condition instead of wrapping the body in if."],
];
const HINTS = new Map(RULES.map(([rule, , , hint]) => [rule, hint]));

export function makeFinding(site, verdict, message) {
  const [file, line] = site;
  const [rule, severity] = verdict;
  return { file, line, rule, severity, message, fix_hint: HINTS.get(rule) };
}

export function describeRules() {
  return RULES.map(([rule, severity, description, hint]) => ({ rule, severity, description, fix_hint: hint }));
}
