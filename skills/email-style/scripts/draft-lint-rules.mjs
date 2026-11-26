export const HEADER_SCAN_LINES = 10;
export const CLOSING_SCAN_LINES = 5;
export const MAX_OPENING_SENTENCES = 2;
const GREETING_SHAPE = /^\S+(?:\s+\S+){0,5},\s*$/;

const BANNED = [
  /hope you['’]?re (?:doing )?well/,
  /hope this (?:email|message) finds you/,
  /thanks so much/,
  /please don['’]?t hesitate/,
  /as outlined above/,
  /as (?:\w+ly )?discussed in our (?:\w+ )?correspondence/,
  /as \w+ly discussed/,
  /pursuant/,
  /aforementioned/,
  /\bleverage\b/,
  /ensure alignment/,
  /i went back and reviewed/,
];
const TZ = /\b\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?\s*(?:CDT|CST|CT|Central|EDT|EST|ET|Eastern|MDT|MST|MT|Mountain|PDT|PST|PT|Pacific)\b/i;
const EMOJI = /[\u{1F000}-\u{1FAFF}☀-➿⭐⭕️]/u;
const OUTLINE = /^\s*1\.\s/;
const HEADER = /^\*\*([A-Za-z]+):\*\*/;

const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

export function sentenceCount(text) {
  return text.trim().split(/(?<=[.!?])\s+/).filter((s) => /\w/.test(s)).length;
}

export function proseLines(lines) {
  let inFence = false;
  const kept = [];
  lines.forEach((raw, i) => {
    if (raw.trimStart().startsWith("```")) inFence = !inFence;
    else if (!inFence) kept.push([i + 1, raw]);
  });
  return kept;
}

export function styleViolations(prose, tzOk) {
  const out = [];
  for (const [n, raw] of prose) {
    if (BANNED.some((re) => re.test(raw.toLowerCase()))) out.push({ line: n, rule: "banned_phrase" });
    if (EMOJI.test(raw)) out.push({ line: n, rule: "emoji" });
    if (!tzOk && TZ.test(raw)) out.push({ line: n, rule: "tz_label" });
  }
  return out;
}

function headerViolations(body) {
  const seen = new Set();
  for (const [, r] of body.slice(0, HEADER_SCAN_LINES)) {
    const m = HEADER.exec(r);
    if (m) seen.add(m[1].toLowerCase());
  }
  return ["to", "subject"].filter((f) => !seen.has(f)).map((f) => ({ line: 1, rule: `header_missing:${f}` }));
}

function skipHeaders(body) {
  let start = 0;
  while (start < body.length && HEADER.test(body[start][1])) start++;
  return start;
}

function isGreeting(text, greeting) {
  if (greeting) return new RegExp(`^${escapeRe(greeting)}\\s+\\S.*,\\s*$`).test(text);
  return GREETING_SHAPE.test(text);
}

function greetingViolations(body, start, greeting) {
  if (!greeting || (start < body.length && isGreeting(body[start][1].trim(), greeting))) return [];
  return [{ line: start < body.length ? body[start][0] : 1, rule: "greeting_mismatch" }];
}

export function openingViolations(body, start) {
  let outlineIdx = -1;
  for (let i = start; i < body.length; i++) {
    if (OUTLINE.test(body[i][1])) {
      outlineIdx = i;
      break;
    }
  }
  if (outlineIdx === -1 || outlineIdx === start) return [];
  const opening = body.slice(start, outlineIdx).map(([, r]) => r.trim()).join(" ");
  if (sentenceCount(opening) > MAX_OPENING_SENTENCES) return [{ line: body[start][0], rule: "opening_over_2_sentences" }];
  return [];
}

function closingViolations(body, config) {
  const tail = body.slice(-CLOSING_SCAN_LINES);
  const closings = config.closings || [];
  let afterFrom = 0;
  let at = tail.length ? tail[tail.length - 1][0] : 1;
  if (closings.length) {
    const closeAt = tail.findIndex(([, r]) => closings.includes(r.trim()));
    if (closeAt === -1) return [{ line: at, rule: "closing_missing" }];
    afterFrom = closeAt + 1;
    at = tail[closeAt][0];
  }
  const after = tail.slice(afterFrom).map(([, r]) => r).join(" ");
  const phone = String(config.phone ?? "").replace(/\D/g, "");
  const out = [];
  if (config.signature && !after.includes(config.signature)) out.push({ line: at, rule: "signature_missing" });
  if (phone && !after.replace(/\D/g, "").includes(phone)) out.push({ line: at, rule: "phone_missing" });
  return out;
}

function emailViolations(body, config) {
  const out = headerViolations(body);
  let start = skipHeaders(body);
  const greeting = config?.greeting;
  out.push(...greetingViolations(body, start, greeting));
  if (start < body.length && isGreeting(body[start][1].trim(), greeting)) start++;
  out.push(...openingViolations(body, start));
  if (config === null) process.stderr.write("warning: no config, greeting, closing, signature and phone checks skipped\n");
  else out.push(...closingViolations(body, config));
  return out;
}

export function lint(lines, profile, settings) {
  const [config, tzOk] = settings;
  const prose = proseLines(lines);
  const out = styleViolations(prose, tzOk);
  const body = prose.filter(([, r]) => r.trim());
  return out.concat(profile === "email" ? emailViolations(body, config) : openingViolations(body, 0));
}
