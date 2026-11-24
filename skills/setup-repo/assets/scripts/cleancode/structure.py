from .struct_brace import build_brace
from .struct_python import build_python
from .struct_ruby import build_ruby
from .struct_shell import build_shell


def count_logic(masked, function):
    last = min(function.end, len(masked) - 1)
    return sum(1 for number in range(function.start, last + 1) if masked[number].strip())


def build_structure(spec, lexed):
    masked = lexed.masked
    if spec.family == "python":
        structure = build_python(masked, lexed.triples)
    elif spec.family == "shell":
        structure = build_shell(lexed.raw, masked)
    elif spec.family == "ruby":
        structure = build_ruby(masked)
    else:
        structure = build_brace(masked, spec.name)
    for function in structure.functions:
        function.logic = count_logic(masked, function)
    return structure
