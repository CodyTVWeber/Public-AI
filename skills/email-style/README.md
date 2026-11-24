# email-style

Draft outbound email in a plain, scannable business voice: nested outline, delta only, light source tags, document-shaped asks. Never sends; drafts are files awaiting a go-ahead.

## Install

### Claude Code

```bash
cp <path-to-this-repo>/skills/email-style/email-style.md ~/.claude/commands/email-style.md
```

### Other agents

```bash
ln -sfn <path-to-this-repo>/skills/email-style ~/.agents/skills/email-style
```

## Invoke

- `/email-style`
- "Draft an email in my voice"
- "Not AI-sounding"

## Config

Optional JSON at `~/.config/ai-skills/email-style.json` (or `$AI_SKILLS_EMAIL_CONFIG`, or `--config PATH`):

```json
{"greeting": "Hi", "closings": ["Thanks,"], "signature": "Sender Name", "phone": "x0000"}
```

## Files

| File | Role |
|---|---|
| `email-style.md` (`SKILL.md` links to it) | Agent instructions |
| `references/style-guide.md` | Voice detail, banned phrases, example |
| `scripts/draft-lint.py FILE [--profile email\|output] [--config PATH] [--skip R] [--recipient-elsewhere]` | JSON `[{line, rule}]`; exit 0 clean, 1 violations, 2 usage |
| `scripts/draft-path.sh [--dir D] TOPIC` | JSON `{path}` for `draft-<topic>.md` |
| `scripts/tests/email-style.test.sh` | Runs the python3 tests |

Related: [outline-output](../outline-output/) applies the same shape to all agent output.
