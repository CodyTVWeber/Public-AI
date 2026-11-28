const PART_COUNT = 3;

export function nextPatch(version) {
  const parts = String(version).split(".");
  if (parts.length !== PART_COUNT || parts.some((part) => !/^\d+$/.test(part))) {
    throw new Error("public-ai-sync: package version is not major.minor.patch");
  }
  return `${parts[0]}.${parts[1]}.${Number(parts[2]) + 1}`;
}
