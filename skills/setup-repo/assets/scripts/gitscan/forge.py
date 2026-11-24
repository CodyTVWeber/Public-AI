from .tags import FORGE_WRITE, MR_CREATE

BINS = ("gh", "glab")
WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}
FIELD_FLAGS = {"-f", "-F", "--field", "--raw-field", "--input"}
FIELD_PREFIXES = ("--field=", "--raw-field=", "--input=")
METHOD_FLAGS = {"-X", "--method"}
VALUE_FLAGS = {"-R", "--repo", "--hostname"}
REQUEST_NOUNS = ("pr", "mr")


def positional(args):
    words, skip = [], False
    for arg in args:
        if skip:
            skip = False
        elif arg in VALUE_FLAGS:
            skip = True
        elif not arg.startswith("-"):
            words.append(arg)
    return words


def is_field_flag(arg):
    if arg in FIELD_FLAGS or arg.startswith(FIELD_PREFIXES):
        return True
    return len(arg) > 2 and arg[:2] in ("-f", "-F") and not arg.startswith("--")


def method_of(args):
    method = None
    for pos, arg in enumerate(args):
        if arg in METHOD_FLAGS and pos + 1 < len(args):
            method = args[pos + 1]
        elif arg.startswith("--method="):
            method = arg.split("=", 1)[1]
        elif arg.startswith("-X") and len(arg) > 2:
            method = arg[2:]
    return method


def api_writes(args):
    if "graphql" in args:
        return any("mutation" in arg.lower() for arg in args)
    method = method_of(args)
    if method is not None:
        return method.upper() in WRITE_METHODS
    return any(is_field_flag(arg) for arg in args)


def scan(args, found):
    words = positional(args)[:2]
    if len(words) == 2 and words[0] in REQUEST_NOUNS and words[1] == "create":
        found.add(MR_CREATE)
    elif len(words) == 2 and words[0] in REQUEST_NOUNS and words[1] == "merge":
        found.add(FORGE_WRITE)
    elif words[:1] == ["api"] and api_writes(args):
        found.add(FORGE_WRITE)
