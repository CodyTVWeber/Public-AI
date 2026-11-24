from .headers_brace import detect_headers
from .model import Structure
from .walker_brace import Walker


def build_brace(masked, lang):
    headers = detect_headers(masked, lang)
    opens = {body: function for function, body in headers if body}
    blocks = Walker(opens).run(masked)
    return Structure([function for function, _ in headers], blocks)
