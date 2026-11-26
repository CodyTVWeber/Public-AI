---
name: process-recording
description: >
  Locally transcribe a recording; extract owner-dated actions. Use to process,
  transcribe, or pull tasks from audio or video of a conversation or meeting.
---

# Process recording

Output: transcript + action table.

## Steps

1. **Transcribe locally** if a local tool can. Upload only if user asked.
2. **Extract actionable items**, labeled **committed**, **conditional**, or **optional**. Drop scene chatter. Keep actionable optionals. Per row:
   - action
   - owner (assignee, if spoken)
   - date (if spoken)
   - tier: **committed** / **conditional** / **optional**
   - confidence: clear | quiet/uncertain
3. **Cross-check** quiet or uncertain speech with supported audio/video review. Ambiguity left → **flag**. No invented replay. No guess → task.
4. **Dedupe** against the **actual** task list before filing: `scripts/dedupe-tasks.mjs NEW.json EXISTING.json` → `{new, duplicates}` (exact match after normalizing). Link existing item per duplicate. Judge near-matches yourself.
5. **File** in the task list the user names, on the owner's behalf. Filer ≠ assignee is fine.

## Never

- Infer **completion** from tone, memory, "I think we did that"
- File **scene chatter** (jokes, someday-ideas, unowned musing) as tasks
- Drop **actionable optional** requests
- Invent owners or dates
- Skip the existing-task check
