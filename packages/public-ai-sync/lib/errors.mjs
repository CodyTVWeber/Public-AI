export class SyncError extends Error {
  constructor(message, code = 1) {
    super(message);
    this.name = "SyncError";
    this.code = code;
  }
}

export function printFail(err) {
  const raw = err && err.message ? err.message : "failed";
  const line = raw.startsWith("public-ai-sync:") ? raw : `public-ai-sync: ${raw}`;
  process.stderr.write(`${line}\n`);
  return err instanceof SyncError ? err.code : 1;
}
