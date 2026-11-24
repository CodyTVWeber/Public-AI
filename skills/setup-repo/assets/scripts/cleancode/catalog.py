from .model import ERROR, WARN, Finding

BOTH = "error/warn"

RULES = (
    ("added-comment", ERROR, "Comment added or touched; code ships with no comments (tests included)",
     "Delete the comment: rename, extract a named function, or name the constant (rules/ban-comments.md)."),
    ("docstring", WARN, "Python docstring attached to a module, class or function",
     "Name the code so it needs no docstring; a free-floating string used as a comment is an error."),
    ("todo-marker", ERROR, "TODO, FIXME or XXX in an added comment",
     "Move it to the tracker; code ships with no TODO markers."),
    ("banner", ERROR, "Section banner or STATUS: line",
     "Order the file (public API first, helpers below); docs describe the present."),
    ("empty-catch", ERROR, "Empty catch/except handler",
     "Call a named helper such as ignoreOptionalFailure(err) instead of an empty handler."),
    ("param-count", BOTH, "Function with 4+ params (error) or 3 params (warn)",
     "Group related params into an options object or split the function."),
    ("function-length", BOTH, "Function over 80 logic lines (error) or 40 (warn)",
     "Extract named functions until the body is 40 lines of logic or fewer."),
    ("nesting-depth", BOTH, "Control-flow nesting of 4+ (error) or 3 (warn)",
     "Use early returns and guard clauses or extract a named function."),
    ("file-size", BOTH, "File over 400 lines (error) or 200 (warn) that the change grows",
     "Extract a module before growing the file; one responsibility per file."),
    ("param-mutation", BOTH, "Assignment to a parameter's property or index, or compound assignment to a parameter (warn for res, req, ctx, event and ref.current idioms)",
     "Compute and return a new value; the caller assigns. If mutation is the point, name the function so."),
    ("bool-flag-param", WARN, "Boolean flag parameter named is*, has*, should* or enable*",
     "Replace the boolean with an enum that names each outcome, or split into two functions."),
    ("magic-number", WARN, "Numeric literal other than -1, 0, 1, 2 outside a named constant",
     "Extract a named constant that states the meaning."),
    ("layer-folder", WARN, "New file under a controller, service or model folder",
     "Group by feature or domain instead of by technical layer."),
    ("duplicate-string", WARN, "Same string literal (6+ chars) three or more times in a file",
     "Extract a named constant and reuse it."),
    ("inline-try-catch", WARN, "Non-trivial try/catch inline in a function longer than 10 lines",
     "Move the try/catch into a named function that states the attempt, such as readCachedProfile()."),
)
HINTS = {rule: hint for rule, _, _, hint in RULES}
RULE_IDS = frozenset(HINTS)


def make_finding(site, verdict, message):
    path, line = site
    rule, severity = verdict
    return Finding(path, line, rule, severity, message, HINTS[rule])


def describe_rules():
    return [
        {"rule": rule, "severity": severity, "description": text, "fix_hint": hint}
        for rule, severity, text, hint in RULES
    ]
