#!/usr/bin/env python3
import argparse
import datetime
import json
import sys

DESCRIPTION = """Print the dates of the weekend a weekend list covers, as JSON.
Mon-Fri: the coming Saturday and Sunday. Saturday: today and tomorrow.
Sunday: yesterday and today. Also friday and next_monday for carryover and weekday prep.
--today YYYY-MM-DD overrides the date. Exit: 0 ok, 2 usage."""


def weekend(today):
    weekday = today.weekday()
    saturday = today - datetime.timedelta(days=1) if weekday == 6 else today + datetime.timedelta(days=(5 - weekday) % 7)
    return {
        "today": today,
        "friday": saturday - datetime.timedelta(days=1),
        "saturday": saturday,
        "sunday": saturday + datetime.timedelta(days=1),
        "next_monday": saturday + datetime.timedelta(days=2),
    }


def main():
    parser = argparse.ArgumentParser(prog="weekend-dates.py", description=DESCRIPTION, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--today")
    args = parser.parse_args()
    try:
        today = datetime.date.fromisoformat(args.today) if args.today else datetime.date.today()
    except ValueError:
        sys.stderr.write("--today must be YYYY-MM-DD\n")
        sys.exit(2)
    print(json.dumps({k: v.isoformat() for k, v in weekend(today).items()}))


if __name__ == "__main__":
    main()
