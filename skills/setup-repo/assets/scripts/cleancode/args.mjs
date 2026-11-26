export class UsageError extends Error {}

const MODES = ["staged", "changed", "range", "hook", "stop_hook", "list_rules"];
const FLAGS = {
  "--staged": "staged", "--hook": "hook", "--stop-hook": "stop_hook",
  "--list-rules": "list_rules", "--all-lines": "all_lines",
};

function setMode(args, mode, value) {
  const taken = MODES.find((name) => name !== mode && args[name] !== undefined && args[name] !== false);
  if (taken) throw new UsageError(`argument --${mode.replace("_", "-")}: not allowed with another mode`);
  args[mode] = value;
}

function takeValue(argv, index, name) {
  const next = argv[index + 1];
  if (next === undefined || (next.startsWith("-") && next !== "-")) throw new UsageError(`argument ${name}: expected one argument`);
  return next;
}

function applyOption(args, argv, index) {
  const [flag, inline] = argv[index].split(/=(.*)/s);
  if (flag in FLAGS) {
    const key = FLAGS[flag];
    if (key === "all_lines") args.all_lines = true;
    else setMode(args, key, true);
    return index + 1;
  }
  if (flag === "--range") {
    const value = inline === undefined ? takeValue(argv, index, flag) : inline;
    setMode(args, "range", value);
    return index + (inline === undefined ? 2 : 1);
  }
  if (flag === "--changed") return applyChanged(args, [argv, index], inline);
  throw new UsageError("unrecognized arguments: " + argv[index]);
}

function applyChanged(args, [argv, index], inline) {
  if (inline !== undefined) {
    setMode(args, "changed", inline);
    return index + 1;
  }
  const next = argv[index + 1];
  const hasBase = next !== undefined && !next.startsWith("-");
  setMode(args, "changed", hasBase ? next : "HEAD");
  return index + (hasBase ? 2 : 1);
}

export function parseArgs(argv) {
  const args = { files: [], all_lines: false, help: false };
  let index = 0;
  let literal = false;
  while (index < argv.length) {
    const item = argv[index];
    if (!literal && item === "--") {
      literal = true;
      index += 1;
    } else if (!literal && (item === "-h" || item === "--help")) {
      args.help = true;
      index += 1;
    } else if (!literal && item.startsWith("-") && item !== "-") {
      index = applyOption(args, argv, index);
    } else {
      args.files.push(item);
      index += 1;
    }
  }
  return args;
}
