import { makeFinding } from "./catalog.mjs";
import { WARN, escapeRegExp } from "./model.mjs";
import { sameBlock } from "./rules_order_span.mjs";

const ORDER = ["function-order", WARN];

export function callFindings(ctx, functions) {
  const graph = callGraph(ctx.src, functions);
  const ids = componentIds(graph);
  const lookup = new Map(functions.map((func) => [func.name, func]));
  const findings = [];
  for (const [name, callees] of graph) {
    const caller = lookup.get(name);
    if (!ctx.change.touches(caller.start, caller.end)) continue;
    const above = callees.filter((callee) => (
      lookup.get(callee).start < caller.start && !sameCycle(ids, { left: name, right: callee })
    ));
    above.sort();
    if (!above.length) continue;
    const listed = above.map((callee) => `${callee}()`).join(", ");
    const message = `${name}() calls ${listed} defined above it; callers stay above callees`;
    findings.push(makeFinding([ctx.src.path, caller.start], ORDER, message));
  }
  return findings;
}

function callGraph(src, functions) {
  const names = uniqueNames(functions);
  const source = callSource(names, src.lang === "shell");
  const lookup = new Map(functions.map((func) => [func.name, func]));
  const graph = new Map();
  for (const func of functions) {
    if (!names.has(func.name)) continue;
    const callees = [...callsFrom(src, { func, source })].filter((name) => (
      names.has(name) && sameBlock(src, { left: func, right: lookup.get(name) })
    ));
    if (callees.length) graph.set(func.name, callees);
  }
  return graph;
}

function componentIds(graph) {
  const state = makeState(graph);
  const nodes = new Set(graph.keys());
  for (const callees of graph.values()) for (const name of callees) nodes.add(name);
  for (const node of nodes) if (!state.index.has(node)) enter(state, node);
  return state.ids;
}

function sameCycle(ids, pair) {
  const id = ids.get(pair.left);
  return id !== undefined && id === ids.get(pair.right);
}

function uniqueNames(functions) {
  const counts = new Map();
  for (const func of functions) counts.set(func.name, (counts.get(func.name) || 0) + 1);
  return new Set([...counts].filter(([, count]) => count === 1).map(([name]) => name));
}

function callSource(names, shell) {
  if (!names.size) return "";
  const parts = [...names].sort((a, b) => b.length - a.length).map(escapeRegExp).join("|");
  const open = String.fromCharCode(123);
  if (shell) return `(?:^|[;&|(\`${open}])\\s*(?:(?:then|do|else|elif)\\s+)?(${parts})\\b`;
  return `\\b(${parts})\\s*\\(`;
}

function callsFrom(src, scan) {
  const found = new Set();
  if (!scan.source) return found;
  const own = new RegExp(`\\b${escapeRegExp(scan.func.name)}\\b`);
  for (let number = scan.func.start; number <= scan.func.end; number++) {
    const raw = src.masked[number];
    const text = number === scan.func.start ? raw.replace(own, " ") : raw;
    for (const match of text.matchAll(new RegExp(scan.source, "g"))) {
      if (match[1] !== scan.func.name) found.add(match[1]);
    }
  }
  return found;
}

function makeState(graph) {
  return {
    graph, index: new Map(), low: new Map(), stack: [], onStack: new Set(),
    ids: new Map(), counter: [0], comp: [0],
  };
}

function enter(state, node) {
  const { index, low, stack, onStack, graph, counter } = state;
  index.set(node, counter[0]);
  low.set(node, counter[0]);
  counter[0] += 1;
  stack.push(node);
  onStack.add(node);
  for (const next of graph.get(node) || []) link(state, { node, next });
  if (low.get(node) === index.get(node)) closeComponent(state, node);
}

function link(state, edge) {
  const { index, low, onStack } = state;
  if (!index.has(edge.next)) {
    enter(state, edge.next);
    low.set(edge.node, Math.min(low.get(edge.node), low.get(edge.next)));
    return;
  }
  if (onStack.has(edge.next)) low.set(edge.node, Math.min(low.get(edge.node), index.get(edge.next)));
}

function closeComponent(state, node) {
  const members = [];
  let next = null;
  do {
    next = state.stack.pop();
    state.onStack.delete(next);
    members.push(next);
  } while (next !== node);
  if (members.length < 2) return;
  const comp = state.comp;
  comp[0] += 1;
  for (const member of members) state.ids.set(member, comp[0]);
}
