import * as gitparse from "./gitparse.mjs";
import { COMMIT_LIKE, DENY_HOOKSPATH, DENY_NO_VERIFY, PUSH_LIKE } from "./tags.mjs";

export const KNOWN = new Set(`add am annotate apply archive backfill bisect blame branch bugreport bundle cat-file
check-attr check-ignore check-mailmap check-ref-format checkout checkout-index cherry cherry-pick
clean clone column commit commit-graph commit-tree config count-objects credential describe diagnose
diff diff-files diff-index diff-tree difftool fast-export fast-import fetch fetch-pack filter-branch
fmt-merge-msg for-each-ref for-each-repo format-patch fsck gc get-tar-commit-id grep hash-object help
hook http-fetch http-push index-pack init interpret-trailers last-modified log ls-files ls-remote
ls-tree mailinfo mailsplit maintenance merge merge-base merge-file merge-index merge-tree mergetool
mktag mktree multi-pack-index mv name-rev notes pack-objects pack-redundant pack-refs patch-id prune
prune-packed pull push range-diff read-tree rebase reflog refs remote repack replace replay
request-pull rerere reset restore rev-list rev-parse revert rm scalar send-email send-pack shortlog
show show-branch show-index show-ref sparse-checkout stash status stripspace submodule switch
symbolic-ref tag unpack-file unpack-objects update-index update-ref update-server-info var
verify-commit verify-pack verify-tag version whatchanged worktree write-tree`.split(/\s+/));
const TRACKED = new Set(["commit", "push", "merge", "pull"]);
const COMMIT_LIKE_SUBS = new Set(["merge", "cherry-pick", "revert", "am", "commit-tree", "update-ref",
  "filter-branch", "fast-import"]);
const PUSH_LIKE_SUBS = new Set(["send-pack", "http-push"]);
const NO_VERIFY_SUBS = new Set([...COMMIT_LIKE_SUBS, "pull", "rebase"]);
const CONFIG_VALUE_OPTS = new Set(["-f", "--file", "--blob", "--default", "--type", "--comment"]);
const CONFIG_READ_FLAGS = new Set(["--get", "--get-all", "--get-regexp", "--get-urlmatch", "--list", "-l",
  "--unset", "--unset-all", "--name-only"]);
const EXEC_MIN = 4;
const SHORT_EXEC = /^-[a-zA-Z]*x/;

export function scan(sub, rest, found) {
  if (TRACKED.has(sub)) found.add(sub);
  if (sub === "commit") gitparse.scanCommit(rest, found);
  if (sub === "push") gitparse.scanPush(rest, found);
  if (COMMIT_LIKE_SUBS.has(sub)) found.add(COMMIT_LIKE);
  if (PUSH_LIKE_SUBS.has(sub)) found.add(PUSH_LIKE);
  if (NO_VERIFY_SUBS.has(sub)) scanNoVerify(sub, rest, found);
  if (sub === "config" && configWritesHooksPath(rest)) found.add(DENY_HOOKSPATH);
  return embeddedCommands(sub, rest, found);
}

function bypassesVerify(sub, arg) {
  if (arg.startsWith("--")) return gitparse.abbreviation(arg.split("=")[0], "--no-verify");
  return sub === "am" && arg.startsWith("-") && arg.includes("n");
}

function scanNoVerify(sub, rest, found) {
  const stop = rest.indexOf("--");
  const args = stop >= 0 ? rest.slice(0, stop) : rest;
  if (args.some((arg) => bypassesVerify(sub, arg))) found.add(DENY_NO_VERIFY);
}

function splitConfigArgs(rest) {
  const words = [];
  const flags = new Set();
  let skip = false;
  for (const arg of rest) {
    if (skip) skip = false;
    else if (CONFIG_VALUE_OPTS.has(arg)) skip = true;
    else if (arg.startsWith("-")) flags.add(arg.split("=")[0]);
    else words.push(arg.toLowerCase());
  }
  return [words, flags];
}

function configWritesHooksPath(rest) {
  const [words, flags] = splitConfigArgs(rest);
  if (!words.includes(gitparse.HOOKS_KEY) || [...flags].some((f) => CONFIG_READ_FLAGS.has(f))) return false;
  if (flags.has("--add") || flags.has("--replace-all")) return true;
  return words.indexOf(gitparse.HOOKS_KEY) < words.length - 1;
}

function embeddedCommands(sub, rest, found) {
  if (sub === "rebase") return execCommands(rest, "--exec", found);
  if (sub === "difftool" || sub === "mergetool") return execCommands(rest, "--extcmd", null);
  if (sub === "submodule") return foreachCommand(rest, found);
  if (sub === "bisect" && rest.includes("run")) return [gitparse.quoteAll(rest.slice(rest.indexOf("run") + 1))];
  return [];
}

function execValue(arg, following, longName) {
  if (arg.startsWith("--")) {
    const at = arg.indexOf("=");
    const name = at < 0 ? arg : arg.slice(0, at);
    if (!gitparse.abbreviation(name, longName, EXEC_MIN)) return null;
    return at >= 0 ? arg.slice(at + 1) : (following.length ? following[0] : "");
  }
  if (SHORT_EXEC.test(arg)) return arg.slice(arg.indexOf("x") + 1) || (following.length ? following[0] : "");
  return null;
}

function execCommands(rest, longName, found) {
  const values = rest.map((arg, pos) => execValue(arg, rest.slice(pos + 1, pos + 2), longName));
  const commands = values.filter((value) => value !== null);
  if (commands.length && found) found.add(COMMIT_LIKE);
  return commands;
}

function foreachCommand(rest, found) {
  const words = rest.filter((arg) => !arg.startsWith("-"));
  if (!words.length || words[0] !== "foreach") return [];
  found.add(COMMIT_LIKE);
  return [rest.slice(rest.indexOf("foreach") + 1).join(" ")];
}
