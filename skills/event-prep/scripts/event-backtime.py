#!/usr/bin/env python3
import argparse
import datetime
import json
import sys

DESCRIPTION = """Work backward from an event start to a chronological schedule.
Steps (earliest first): prep (optional), get-ready, load, depart, arrive, event start.
Durations are labeled recommendation unless named in --stated (comma list of
buffer, drive, load, getready, prep); the drive duration is labeled estimate otherwise.
Default stdout is JSON; --text prints a table instead. Times keep the --start offset, if any.
--start takes ISO 8601 (for example 2026-01-02T14:30). Exit: 0 ok, 2 usage."""

DURATIONS = ("prep", "getready", "load", "drive", "buffer")


def build(start, minutes, stated):
    def label(name):
        if name in stated:
            return "stated"
        return "estimate" if name == "drive" else "recommendation"

    steps = [("Event start", start, 0, "stated")]
    clock = start
    for name, step in (("buffer", "Arrive"), ("drive", "Depart"), ("load", "Load"), ("getready", "Get ready"), ("prep", "Prep")):
        if name == "prep" and not minutes[name]:
            continue
        clock = clock - datetime.timedelta(minutes=minutes[name])
        steps.append((step, clock, minutes[name], label(name)))
    return [{"step": s, "time": t.isoformat(), "clock": t.strftime("%H:%M"), "minutes_to_next": m, "basis": b} for s, t, m, b in reversed(steps)]


def main():
    parser = argparse.ArgumentParser(prog="event-backtime.py", description=DESCRIPTION, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--start", required=True)
    parser.add_argument("--buffer-min", type=int, required=True)
    parser.add_argument("--drive-min", type=int, required=True)
    parser.add_argument("--load-min", type=int, required=True)
    parser.add_argument("--getready-min", type=int, required=True)
    parser.add_argument("--prep-min", type=int, default=0)
    parser.add_argument("--stated", default="")
    parser.add_argument("--text", action="store_true")
    args = parser.parse_args()
    try:
        start = datetime.datetime.fromisoformat(args.start)
    except ValueError:
        sys.stderr.write("--start must be ISO 8601\n")
        sys.exit(2)
    minutes = {"buffer": args.buffer_min, "drive": args.drive_min, "load": args.load_min, "getready": args.getready_min, "prep": args.prep_min}
    if any(v < 0 for v in minutes.values()):
        sys.stderr.write("durations must be >= 0\n")
        sys.exit(2)
    stated = {s.strip() for s in args.stated.split(",") if s.strip()}
    if not stated <= set(DURATIONS):
        sys.stderr.write(f"--stated accepts: {', '.join(DURATIONS)}\n")
        sys.exit(2)
    schedule = build(start, minutes, stated)
    if args.text:
        print("| Time | Step | Basis |\n|---|---|---|")
        for row in schedule:
            print(f"| {row['clock']} | {row['step']} | {row['basis']} |")
    else:
        print(json.dumps({"schedule": schedule}))


if __name__ == "__main__":
    main()
