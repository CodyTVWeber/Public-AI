#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { readFileSync, statSync } from "node:fs";
import { basename, extname } from "node:path";
import { parseArgs } from "node:util";

const MIME = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".mp4": "video/mp4",
  ".webm": "video/webm",
};

const DESCRIPTION = `Usage: upload-evidence.mjs PROJECT_ID FILE... [--host HOST] [--dry-run] [--max-bytes N]
Upload evidence files to a GitLab project and print {filename: markdown} as JSON.

Token: GL_TOKEN (for example GL_TOKEN=$(glab config get token --host <host>)).
Host: --host, else $GL_HOST, else the host of the origin git remote.
Types: png jpg jpeg gif webp mp4 webm.
Exit: 0 ok, 2 usage or bad input, 3 missing token or host, 4 upload failure.
On failure stdout carries {"error": ..., "file": ...}; details go to stderr.`;

function fail(code, message, path = null) {
  process.stderr.write(`${message}\n`);
  console.log(JSON.stringify({ error: message, file: path }));
  process.exit(code);
}

function hostFromRemote() {
  let url;
  try {
    url = execFileSync("git", ["config", "--get", "remote.origin.url"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return null;
  }
  const match = /^(?:[a-z+]+:\/\/)?(?:[^@/]+@)?([^:/]+)/i.exec(url);
  return match ? match[1] : null;
}

function fileSize(path) {
  try {
    const st = statSync(path);
    return st.isFile() ? st.size : null;
  } catch {
    return null;
  }
}

function checkFile(path, maxBytes) {
  const ext = extname(path).toLowerCase();
  if (!MIME[ext]) fail(2, `unsupported extension: ${ext || "(none)"}`, path);
  const size = fileSize(path);
  if (size === null) fail(2, "file not found", path);
  if (size === 0) fail(2, "file is empty", path);
  if (size > maxBytes) fail(2, `file is ${size} bytes, over the ${maxBytes} byte limit`, path);
  return { path, mime: MIME[ext], size };
}

function multipart(file) {
  const boundary = randomBytes(16).toString("hex");
  const name = basename(file.path).replaceAll('"', "_");
  const head = `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${name}"\r\nContent-Type: ${file.mime}\r\n\r\n`;
  const body = Buffer.concat([Buffer.from(head), readFileSync(file.path), Buffer.from(`\r\n--${boundary}--\r\n`)]);
  return { body, type: `multipart/form-data; boundary=${boundary}` };
}

async function upload(target, file) {
  const { body, type } = multipart(file);
  let resp;
  try {
    resp = await fetch(`${target.host}/api/v4/projects/${target.projectId}/uploads`, {
      method: "POST",
      body,
      headers: { "PRIVATE-TOKEN": target.token, "Content-Type": type },
      signal: AbortSignal.timeout(120000),
    });
  } catch (e) {
    fail(4, `upload failed: ${e.name}`, file.path);
  }
  if (!resp.ok) fail(4, `upload failed: HTTP ${resp.status}`, file.path);
  try {
    return (await resp.json()).markdown ?? fail(4, "upload failed: KeyError", file.path);
  } catch {
    return fail(4, "upload failed: ValueError", file.path);
  }
}

function parse() {
  const options = {
    host: { type: "string" },
    "dry-run": { type: "boolean" },
    "max-bytes": { type: "string", default: String(100 * 1024 * 1024) },
    help: { type: "boolean", short: "h" },
  };
  let parsed;
  try {
    parsed = parseArgs({ options, allowPositionals: true });
  } catch (e) {
    fail(2, `${DESCRIPTION}\n${e.message}`);
  }
  if (parsed.values.help) {
    console.log(DESCRIPTION);
    process.exit(0);
  }
  if (parsed.positionals.length < 2) fail(2, DESCRIPTION);
  if (!/^\d+$/.test(parsed.values["max-bytes"])) fail(2, "--max-bytes needs an integer");
  return parsed;
}

async function main() {
  const { values, positionals } = parse();
  const [projectId, ...paths] = positionals;
  const checked = paths.map((p) => checkFile(p, Number(values["max-bytes"])));
  if (values["dry-run"]) {
    const files = checked.map((f) => ({ file: basename(f.path), mime: f.mime, bytes: f.size }));
    console.log(JSON.stringify({ dry_run: true, files }));
    return;
  }
  const host = values.host || process.env.GL_HOST || hostFromRemote();
  if (!host) fail(3, "no host: pass --host, set GL_HOST, or run inside a repo with an origin remote");
  const token = process.env.GL_TOKEN;
  if (!token) fail(3, "GL_TOKEN is not set");
  const target = { host: (host.includes("://") ? host : `https://${host}`).replace(/\/+$/, ""), projectId, token };
  const result = {};
  for (const f of checked) result[basename(f.path)] = await upload(target, f);
  console.log(JSON.stringify(result));
}

main();
