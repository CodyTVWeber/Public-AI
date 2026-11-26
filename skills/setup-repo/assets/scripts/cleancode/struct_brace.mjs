import { detectHeaders } from "./headers_brace.mjs";
import { Walker } from "./walker_brace.mjs";

export function buildBrace(masked, lang) {
  const headers = detectHeaders(masked, lang);
  const opens = new Map();
  for (const [func, body] of headers) if (body) opens.set(`${body[0]},${body[1]}`, func);
  const blocks = new Walker(opens).run(masked);
  return { functions: headers.map(([func]) => func), blocks };
}
