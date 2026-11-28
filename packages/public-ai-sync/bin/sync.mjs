#!/usr/bin/env node
import { printFail } from "../lib/errors.mjs";
import { run } from "../lib/run.mjs";

try {
  process.exit(run(process.argv.slice(2)));
} catch (err) {
  process.exit(printFail(err));
}
