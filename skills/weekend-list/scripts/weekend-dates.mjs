#!/usr/bin/env node
import { parseArgs } from "node:util";

const DESCRIPTION = `Usage: weekend-dates.mjs [--today YYYY-MM-DD]
Print the dates of the weekend a weekend list covers, as JSON.
Mon-Fri: the coming Saturday and Sunday. Saturday: today and tomorrow.
Sunday: yesterday and today. Also friday and next_monday for carryover and weekday prep.
--today YYYY-MM-DD overrides the date. Exit: 0 ok, 2 usage.`;

const DAY_MS = 86400000;
const iso = (ms) => new Date(ms).toISOString().slice(0, 10);

function usage(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

function parseDate(text) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (!m) return null;
  const ms = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return iso(ms) === text ? ms : null;
}

function localToday() {
  const n = new Date();
  return Date.UTC(n.getFullYear(), n.getMonth(), n.getDate());
}

function weekend(today) {
  const weekday = (new Date(today).getUTCDay() + 6) % 7;
  const saturday = weekday === 6 ? today - DAY_MS : today + ((5 - weekday + 7) % 7) * DAY_MS;
  return {
    today: iso(today),
    friday: iso(saturday - DAY_MS),
    saturday: iso(saturday),
    sunday: iso(saturday + DAY_MS),
    next_monday: iso(saturday + 2 * DAY_MS),
  };
}

function main() {
  let values;
  try {
    ({ values } = parseArgs({ options: { today: { type: "string" }, help: { type: "boolean", short: "h" } } }));
  } catch (e) {
    usage(`${DESCRIPTION}\n${e.message}`);
  }
  if (values.help) {
    console.log(DESCRIPTION);
    return;
  }
  const today = values.today ? parseDate(values.today) : localToday();
  if (today === null) usage("--today must be YYYY-MM-DD");
  console.log(JSON.stringify(weekend(today)));
}

main();
