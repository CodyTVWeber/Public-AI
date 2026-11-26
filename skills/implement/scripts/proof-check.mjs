#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { parseBody, section, splitLines } from "./proof-parse.mjs";

const VIDEO = /\.(mp4|webm|mov)(\)|\?|\s|"|$)/i;
const WRITE_SQL = /\b(insert|update|delete|drop|alter|truncate|create|grant)\b/i;
const REVIEW_LABELS = [
  ["start_file", /start here/i],
  ["look_hard", /look hard/i],
  ["out_of_scope", /not in this change|out of scope|not here/i],
];

function truthy(v) {
  if (Array.isArray(v)) return v.length > 0;
  if (v && typeof v === "object") return Object.keys(v).length > 0;
  return Boolean(v);
}

function matches(re, text) {
  return [...text.matchAll(re)];
}

function countMedia(prose) {
  const mediaMd = matches(/!?\[[^\]]*\]\(([^)\s]+)[^)]*\)/g, prose).map((m) => m[1]);
  const images = matches(/!\[[^\]]*\]\(([^)\s]+)/g, prose).map((m) => m[1]);
  return {
    imgs: matches(/<img\b/gi, prose).length + images.filter((u) => !VIDEO.test(`${u})`)).length,
    vids: matches(/<video\b/gi, prose).length + mediaMd.filter((u) => VIDEO.test(`${u})`)).length,
  };
}

function countBlocks(blocks) {
  const isHttp = (b) => ["http", "rest"].includes(b.lang) || /^\s*(GET|POST|PUT|PATCH|DELETE)\s+\S+\s+HTTP\//.test(b.text);
  return {
    curls: blocks.filter((b) => /(^|\s|\$)curl\s/.test(b.text)).length,
    https: blocks.filter(isHttp).length,
    sqls: blocks.filter((b) => b.lang === "sql").map((b) => b.text),
    merm: blocks.filter((b) => b.lang === "mermaid").length,
    curlNeedsFile: blocks.some((b) => /curl\s/.test(b.text) && /\s(-d|--data\S*|-H|--header|-F|--form)\s/.test(b.text)),
  };
}

function checkBuild(sections, add) {
  const b = section(sections, "build");
  if (b === null) return add("heading:Build");
  if (!/`[^`]+`/.test(b)) add("build:command");
  if (!/https?:\/\//.test(b)) add("build:ci_link");
}

function checkReviewGuide(sections, add) {
  const g = section(sections, "review guide");
  if (g === null) return add("heading:Review guide");
  for (const [label, rx] of REVIEW_LABELS) if (!rx.test(g)) add(`review_guide:${label}`);
}

function checkRisk(parsed, add) {
  const risk = section(parsed.sections, "risk");
  const t = risk === null ? null : /\b(low|medium|high)\b/i.exec(risk);
  const tier = t ? t[1].toLowerCase() : null;
  if (tier === null) add("risk:tier");
  if (!/merge policy/i.test(parsed.prose)) add("risk:merge_policy");
  if (tier === "high" && section(parsed.sections, "rollback") === null) add("risk:rollback");
}

function checkProofTable(sections, add) {
  const p = section(sections, "proof");
  if (p === null) return add("heading:Proof");
  const rows = splitLines(p).filter((r) => r.trim().startsWith("|") && !/^\s*\|[\s:|-]+\|?\s*$/.test(r));
  if (rows.length < 2) add("proof:row");
}

function checkTryIt(sections, add) {
  const ti = section(sections, "try it");
  if (ti === null) add("heading:Try it");
  else if (!/^\s*\d+\.\s+\S/m.test(ti)) add("try_it:numbered_steps");
}

function checkBackend(c, add) {
  if (c.curls < 1) add("proof:curl");
  else if (c.curlNeedsFile && c.https < 1) add("proof:http_file");
}

function checkDb(sqls, add) {
  if (!sqls.length) add("proof:query");
  else if (sqls.some((q) => WRITE_SQL.test(q.replace(/--.*/g, "")))) add("proof:query_not_read_only");
}

function checkProof(ctx, add) {
  const { parsed, flag, counts } = ctx;
  checkProofTable(parsed.sections, add);
  checkTryIt(parsed.sections, add);
  if (flag("ui_changed") && counts.imgs < 2) add("proof:before_after_images");
  if (flag("behavior_changed") && counts.vids < 1) add("proof:video");
  if (flag("backend_changed")) checkBackend(counts, add);
  if (flag("db_changed")) checkDb(counts.sqls, add);
  if (flag("deep_change") && counts.merm < 1) add("proof:mermaid");
}

function run(body, scope) {
  const parsed = parseBody(body);
  const flag = (k) => truthy(scope[k]);
  const counts = { ...countMedia(parsed.prose), ...countBlocks(parsed.blocks) };
  const missing = [];
  const add = (m) => missing.push(m);
  checkBuild(parsed.sections, add);
  checkReviewGuide(parsed.sections, add);
  checkRisk(parsed, add);
  const mediaScope = ["ui_changed", "backend_changed", "db_changed"].some(flag);
  const light = (flag("docs_only") || flag("test_only")) && !mediaScope;
  if (!light) checkProof({ parsed, flag, counts }, add);
  else if (!/no behaviou?r change/i.test(parsed.prose)) add("build:no_behavior_change_line");
  if (/`<[^`>\n]+>`|replace with the real call/.test(body)) add("template:placeholder_left");
  const out = { image: counts.imgs, video: counts.vids, curl: counts.curls, http: counts.https, sql: counts.sqls.length, mermaid: counts.merm };
  return { missing, counts: out };
}

const [bodyPath, scopePath] = process.argv.slice(2);
const { missing, counts } = run(readFileSync(bodyPath, "utf8"), JSON.parse(readFileSync(scopePath, "utf8")));
console.log(JSON.stringify({ ok: missing.length === 0, missing, counts }));
for (const m of missing) process.stderr.write(`missing: ${m}\n`);
process.exit(missing.length ? 1 : 0);
