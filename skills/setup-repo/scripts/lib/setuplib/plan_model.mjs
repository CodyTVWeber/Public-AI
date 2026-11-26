import fs from "node:fs";
import path from "node:path";

export class Step {
  constructor(...args) {
    const [id, action, stepPath, reason, extras = {}] = args;
    this.id = id;
    this.action = action;
    this.path = stepPath;
    this.reason = reason;
    this.run = extras.run ?? null;
    this.extra = extras.extra ?? {};
    this.result = null;
  }

  public() {
    const data = { id: this.id, action: this.action, path: this.path, reason: this.reason, ...this.extra };
    if (this.result !== null) data.result = this.result;
    return data;
  }
}

export class Context {
  constructor(fields) {
    Object.assign(this, { cache: {}, installed: new Map(), upgradePaths: new Set(), driftMap: new Map(), drift: [] }, fields);
  }

  get assets() {
    return path.join(this.skillDir, "assets");
  }

  get root() {
    return this.repo.root;
  }

  get local() {
    return this.options.profile === "local";
  }

  get settingsRel() {
    return this.local ? ".claude/settings.local.json" : ".claude/settings.json";
  }

  on(feature) {
    return this.features.includes(feature);
  }

  dest(rel) {
    return path.join(this.root, rel);
  }
}

export function readBytes(file) {
  try {
    return fs.readFileSync(file);
  } catch {
    return null;
  }
}

export function makeExecutable(file) {
  fs.chmodSync(file, fs.statSync(file).mode | 0o111);
}

export function writeBytes(file, data, executable) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, data);
  if (executable) makeExecutable(file);
}

function stateOf(dest, data) {
  const current = readBytes(dest);
  if (current === null) return "create";
  return Buffer.compare(current, Buffer.from(data)) === 0 ? "same" : "differs";
}

export function fileStep(ctx, spec, data) {
  const { id, path: rel } = spec;
  const dest = ctx.dest(rel);
  const state = stateOf(dest, data);
  if (state === "same") return new Step(id, "skip", rel, "already installed and identical");
  if (state === "differs" && !ctx.options.force) {
    return new Step(id, "manual", rel, "exists and differs: diff it and keep the stricter value, or rerun with --force");
  }
  const reason = state === "create" ? (spec.reason ?? "installs the file") : "overwrites the differing file (--force)";
  return new Step(id, "create", rel, reason, { run: () => writeBytes(dest, data, spec.executable ?? false) });
}

export function copyTreeFiles(srcDir, ext) {
  if (!fs.existsSync(srcDir) || !fs.statSync(srcDir).isDirectory()) return [];
  return fs.readdirSync(srcDir).filter((name) => name.endsWith(ext)).sort();
}
