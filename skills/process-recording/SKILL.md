---
name: process-recording
description: >
  Locally transcribe a recording and extract owner-dated actions. Use when
  asked to process, transcribe, or pull tasks from audio or video of a
  conversation or meeting.
---

# Process recording

Deliver the transcript plus the action table.

## Steps

1. **Transcribe locally** when a local tool can do it. Do not upload the recording unless the user asked.
2. **Extract actionable items** — **committed**, **conditional**, and **optional**, each clearly labeled. Keep scene chatter out. Do not drop an actionable optional request. Each row:
   - action
   - owner (assignee, if spoken)
   - date (if spoken)
   - **committed** / **conditional** / **optional**
   - confidence (clear vs quiet/uncertain)
3. **Cross-check quiet or uncertain speech** with supported audio/video review methods. If ambiguity remains, **flag it**. Do not invent replay capability or upgrade a guess into a task.
4. **Dedupe** against the **actual** task list before filing: `scripts/dedupe-tasks.py NEW.json EXISTING.json` → `{new, duplicates}` (exact match after normalizing). Link the existing item for each duplicate; judge near-matches yourself.
5. **File in the task list the user names**, on behalf of the owner. The assignee need not be the one who files.

## Never

- Infer **completion** from tone, memory, or “I think we did that”
- File **scene chatter** (jokes, someday-ideas, unowned musing) as durable tasks
- Drop **actionable optional** requests
- Invent owners or dates
- Skip the existing-task check
